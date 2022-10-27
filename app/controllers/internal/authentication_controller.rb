class Internal::AuthenticationController < InternalController
  def sign_in
    auth_request = AuthRequest.generate!(redirect_path: params[:redirect_path])

    mfa = params[:mfa] == "true"

    render json: {
      auth_uri: oidc_client.auth_uri(auth_request, mfa:),
      state: auth_request.to_oauth_state,
    }
  end

  def callback
    auth_request = AuthRequest.from_oauth_state(params.fetch(:state))
    head :unauthorized and return unless auth_request

    details = oidc_client.callback(auth_request, params.fetch(:code))
    redirect_path = auth_request.redirect_path

    auth_request.delete

    govuk_account_session = AccountSession.new(
      session_secret: Rails.application.secrets.session_secret,
      user_id: details.fetch(:id_token).sub,
      mfa: details.fetch(:mfa),
      digital_identity_session: true,
      version: AccountSession::CURRENT_VERSION,
    )

    capture_sensitive_exceptions(govuk_account_session.user) do
      fetch_cacheable_attributes!(govuk_account_session, details)
    end

    invalidate_logout_notice(govuk_account_session.user.sub)

    render json: {
      govuk_account_session: govuk_account_session.serialise,
      redirect_path:,
    }
  rescue OidcClient::OAuthFailure
    head :unauthorized
  end

  def end_session
    render json: { end_session_uri: oidc_end_session_url }
  end

private

  def oidc_end_session_url
    end_session_endpoint = oidc_client.end_session_endpoint
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

  def fetch_cacheable_attributes!(govuk_account_session, details)
    cacheable_attribute_names = UserAttributes.new.attributes.select { |_, attr| attr[:type] == "cached" }.keys.map(&:to_s)
    attributes_to_cache = cacheable_attribute_names.select { |name| govuk_account_session.user[name].nil? }

    return if attributes_to_cache.empty?

    userinfo = details[:userinfo] || oidc_client.userinfo(access_token: details[:access_token])

    govuk_account_session.set_attributes(userinfo.slice(*attributes_to_cache))
  end

  def oidc_client
    @oidc_client ||=
      if Rails.env.development?
        OidcClient::Fake.new
      else
        OidcClient.new
      end
  end
end
