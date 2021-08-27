class AuthenticationController < ApplicationController
  include DigitalIdentityHelper

  def sign_in
    auth_request = AuthRequest.generate!(redirect_path: params[:redirect_path])

    render json: {
      auth_uri: oidc_client_class.new.auth_uri(auth_request, params.fetch(:level_of_authentication, LevelOfAuthentication::DEFAULT_FOR_SIGN_IN)),
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
        id_token: details.fetch(:id_token_jwt),
        user_id: details.fetch(:id_token).sub,
        access_token: details.fetch(:access_token),
        refresh_token: details.fetch(:refresh_token),
        level_of_authentication: details.fetch(:level_of_authentication),
      ).serialise,
      redirect_path: redirect_path,
      ga_client_id: details.fetch(:ga_session_id),
      cookie_consent: details.fetch(:cookie_consent),
    }
  rescue OidcClient::OAuthFailure
    head :unauthorized
  end

private

  # TODO: Digital Identity don't yet have an implementation of levels
  # of authentication, a way to pass around GA session tokens, or a
  # cookie consent flag.  These will need implementing in some form
  # before we can migrate production.
  def get_level_of_authentication_and_suchlike(client, tokens)
    if using_digital_identity?
      tokens.merge(
        level_of_authentication: "level1",
        ga_session_id: nil,
        cookie_consent: false,
      )
    else
      oauth_response = client.get_ephemeral_state(
        access_token: tokens[:access_token],
        refresh_token: tokens[:refresh_token],
      )

      tokens.merge(
        access_token: oauth_response.fetch(:access_token),
        refresh_token: oauth_response.fetch(:refresh_token),
        level_of_authentication: oauth_response.fetch(:result).fetch("level_of_authentication"),
        ga_session_id: oauth_response.fetch(:result)["_ga"],
        cookie_consent: oauth_response.fetch(:result)["cookie_consent"],
      )
    end
  end
end
