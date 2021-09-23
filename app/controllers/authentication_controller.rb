class AuthenticationController < ApplicationController
  include DigitalIdentityHelper

  def sign_in
    auth_request = AuthRequest.generate!(redirect_path: params[:redirect_path])

    mfa = params[:mfa] == "true"

    render json: {
      auth_uri: oidc_client_class.new.auth_uri(auth_request, mfa: mfa),
      state: auth_request.to_oauth_state,
    }
  end

  def callback
    auth_request = AuthRequest.from_oauth_state(params.fetch(:state))
    head :unauthorized and return unless auth_request

    client = oidc_client_class.new
    tokens = client.callback(auth_request, params.fetch(:code))
    details = get_level_of_authentication_and_suchlike(client, tokens)
    redirect_path = auth_request.redirect_path

    auth_request.delete

    render json: {
      govuk_account_session: AccountSession.new(
        session_secret: Rails.application.secrets.session_secret,
        user_id: details.fetch(:id_token).sub,
        access_token: details.fetch(:access_token),
        refresh_token: details[:refresh_token],
        mfa: details.fetch(:mfa),
      ).serialise,
      redirect_path: redirect_path,
      ga_client_id: details[:ga_session_id],
      cookie_consent: details[:cookie_consent],
    }
  rescue OidcClient::OAuthFailure
    head :unauthorized
  end

  def end_session
    end_session_uri =
      if using_digital_identity?
        oidc_end_session_url
      else
        "#{Plek.find('account-manager')}/sign-out?continue=1"
      end

    render json: { end_session_uri: end_session_uri }
  end

private

  # TODO: Digital Identity will be passing around GA session tokens
  # and cookie consent flags in a different way, likely through query
  # params.
  def get_level_of_authentication_and_suchlike(client, tokens)
    if using_digital_identity?
      tokens.merge(
        mfa: tokens.fetch(:id_token).raw_attributes["vot"] == "Cl.Cm",
      )
    else
      oauth_response = client.get_ephemeral_state(
        access_token: tokens[:access_token],
        refresh_token: tokens[:refresh_token],
      )

      tokens.merge(
        access_token: oauth_response.fetch(:access_token),
        refresh_token: oauth_response.fetch(:refresh_token),
        mfa: oauth_response.fetch(:result).fetch("level_of_authentication") == "level1",
        ga_session_id: oauth_response.fetch(:result)["_ga"],
        cookie_consent: oauth_response.fetch(:result)["cookie_consent"],
      )
    end
  end

  def oidc_end_session_url
    end_session_endpoint = oidc_client_class.new.end_session_endpoint
    id_token = AccountSession.deserialise(
      encoded_session: request.headers["HTTP_GOVUK_ACCOUNT_SESSION"],
      session_secret: Rails.application.secrets.session_secret,
    )&.id_token

    if id_token
      querystring = Rack::Utils.build_nested_query(id_token_hint: id_token)
      "#{end_session_endpoint}?#{querystring}"
    else
      end_session_endpoint
    end
  end
end
