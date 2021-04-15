class AuthenticationController < ApplicationController
  skip_before_action :authorise, only: %i[sign_in callback]

  def sign_in
    AuthRequest.expired.delete_all

    auth_request = AuthRequest.generate!(
      oauth_state: params[:state_id],
      redirect_path: params[:redirect_path],
    )

    render json: {
      auth_uri: OidcClient.new.auth_uri(auth_request),
      state: auth_request.to_oauth_state,
    }
  end

  def callback
    auth_request = AuthRequest.from_oauth_state(params.fetch(:state))
    head :unauthorized and return unless auth_request

    client = OidcClient.new
    tokens = client.callback(auth_request, params.fetch(:code))
    oauth_response = client.get_ephemeral_state(
      access_token: tokens[:access_token],
      refresh_token: tokens[:refresh_token],
    )

    redirect_path = auth_request.redirect_path

    auth_request.delete

    render json: {
      govuk_account_session: to_account_session(
        access_token: oauth_response.fetch(:access_token),
        refresh_token: oauth_response.fetch(:refresh_token),
        level_of_authentication: oauth_response.fetch(:result).fetch("level_of_authentication"),
      ),
      redirect_path: redirect_path,
      ga_client_id: oauth_response.fetch(:result)["_ga"],
    }
  rescue OidcClient::OAuthFailure
    head :unauthorized
  end

  def create_state
    payload = {
      attributes: params[:attributes].permit!.to_h,
    }.compact

    client = OidcClient.new
    tokens = client.tokens!
    oauth_response = client.submit_jwt(
      jwt: JWT.encode(payload, nil, "none"),
      access_token: tokens[:access_token],
      refresh_token: tokens[:refresh_token],
    )

    render json: {
      state_id: oauth_response[:result]["id"],
    }
  end
end
