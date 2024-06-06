require "json/jwt"
require "openid_connect"

class OidcClient
  class OAuthFailure < RuntimeError; end
  class BackchannelLogoutFailure < RuntimeError; end

  attr_reader :client_id,
              :provider_uri

  delegate :authorization_endpoint,
           :token_endpoint,
           :userinfo_endpoint,
           :end_session_endpoint,
           to: :discover

  def initialize
    @provider_uri = Rails.application.credentials.oauth_provider_url
    @client_id = Rails.application.credentials.oauth_client_id
    @secret = Rails.application.credentials.oauth_client_secret

    if Rails.application.credentials.oauth_client_private_key.present?
      @private_key = OpenSSL::PKey::RSA.new Rails.application.credentials.oauth_client_private_key
    end
  end

  def auth_uri(auth_request, mfa: false)
    vtr = Rack::Utils.escape(mfa ? '["Cl.Cm"]' : '["Cl","Cl.Cm"]')
    client.authorization_uri(
      scope: %i[openid email govuk-account],
      state: auth_request.to_oauth_state,
      nonce: auth_request.oidc_nonce,
    ) + "&vtr=#{vtr}"
  end

  def callback(auth_request, code)
    client.authorization_code = code

    tokens = time_and_return "tokens" do
      tokens!(oidc_nonce: auth_request.oidc_nonce)
    end

    @stored_tokens = tokens

    unless OidcUser.where(sub: tokens[:id_token].sub).exists?
      response = userinfo(access_token: tokens[:access_token])
      OidcUser.find_or_create_by_sub!(tokens[:id_token].sub, legacy_sub: response["legacy_subject_id"])
      tokens.merge!(userinfo: response)
    end

    tokens.merge(
      mfa: tokens.fetch(:id_token).raw_attributes["vot"] == "Cl.Cm",
    )
  end

  def tokens!(oidc_nonce: nil)
    access_token =
      if use_client_private_key_auth?
        client.access_token!(
          client_id:,
          client_auth_method: "jwt_bearer",
          client_assertion: JSON::JWT.new(
            iss: client_id,
            sub: client_id,
            aud: token_endpoint,
            jti: SecureRandom.hex(16),
            iat: Time.zone.now.to_i,
            exp: 5.minutes.from_now.to_i,
          ).sign(@private_key, "RS512").to_s,
        )
      else
        client.access_token!
      end

    request_time = Time.zone.now
    response = access_token.token_response

    if oidc_nonce
      id_token_jwt = access_token.id_token
      id_token = OpenIDConnect::ResponseObject::IdToken.decode id_token_jwt, discover.jwks
      id_token.verify! client_id:, issuer: discover.issuer, nonce: oidc_nonce
    end

    {
      access_token: response[:access_token],
      id_token_jwt:,
      id_token:,
      request_time:,
    }.compact
  rescue Rack::OAuth2::Client::Error => e
    capture_sensitive_exception(e)
    raise OAuthFailure
  end

  def userinfo(access_token:)
    response = time_and_return "userinfo" do
      oauth_request(
        access_token:,
        method: :get,
        uri: userinfo_endpoint,
      )
    end

    response.body
  rescue Faraday::ParsingError => e
    capture_sensitive_exception(e, response_error_presenter(response, access_token))
    raise OAuthFailure
  end

  def logout_token(logout_token_jwt)
    logout_token = LogoutToken.decode logout_token_jwt, discover.jwks
    logout_token.verify! client_id:, issuer: discover.issuer
    {
      logout_token_jwt:,
      logout_token:,
      request_time: Time.zone.now,
    }.compact
  rescue JSON::JWS::VerificationFailed => e
    capture_sensitive_exception(e)
    raise BackchannelLogoutFailure
  rescue NoMethodError
    raise BackchannelLogoutFailure
  end

private

  class Retry < StandardError; end

  RETRY_STATUSES = [500, 501, 502, 503, 504].freeze

  MAX_OAUTH_RETRIES = 1

  def response_error_presenter(response, access_token)
    {
      status_code: response&.status,
      response_body: response&.body,
      access_token:,
      tokens_response: @stored_tokens || {},
    }.compact
  end

  def oauth_request(access_token:, method:, uri:, arg: nil)
    args = [uri, arg].compact
    retries = 0

    begin
      response = Rack::OAuth2::AccessToken::Bearer.new(access_token:).public_send(method, *args)
      raise Retry if RETRY_STATUSES.include? response.status

      response
    rescue Retry, Faraday::ConnectionFailed, Faraday::SSLError
      raise OAuthFailure unless retries < MAX_OAUTH_RETRIES

      retries += 1
      retry
    end
  rescue AttrRequired::AttrMissing, Rack::OAuth2::Client::Error, URI::InvalidURIError => e
    capture_sensitive_exception(e)
    raise OAuthFailure
  end

  def redirect_uri
    "#{ENV['GOVUK_WEBSITE_ROOT']}/sign-in/callback"
  end

  def client
    @client ||=
      begin
        client_options = {
          identifier: client_id,
          redirect_uri:,
          authorization_endpoint:,
          token_endpoint:,
          userinfo_endpoint:,
        }

        client_options.merge!(secret: @secret) unless use_client_private_key_auth?
        OpenIDConnect::Client.new(client_options)
      end
  end

  def use_client_private_key_auth?
    @private_key.present?
  end

  def discover
    @discover ||= OpenIDConnect::Discovery::Provider::Config::Response.new cached_discover_response
  end

  def cached_discover_response
    Rails.cache.fetch "oidc/discover/#{provider_uri}" do
      time_and_return "discover" do
        OpenIDConnect::Discovery::Provider::Config.discover!(provider_uri).raw
      end
    end
  end

  def time_and_return(name, &block)
    GovukStatsd.time("oidc_client.#{name}", &block)
  end

  def capture_sensitive_exception(error, extra_info = {})
    captured = SensitiveException.create!(
      message: error.message,
      full_message: error.full_message,
      extra_info: extra_info.to_json,
    )
    GovukError.notify("CapturedSensitiveException", { extra: { sensitive_exception_id: captured.id } })
  end
end
