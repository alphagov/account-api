require "json/jwt"
require "openid_connect"

class OidcClient
  class OAuthFailure < RuntimeError; end

  attr_reader :client_id,
              :provider_uri

  delegate :authorization_endpoint,
           :token_endpoint,
           :userinfo_endpoint,
           :end_session_endpoint,
           to: :discover

  def initialize
    @provider_uri = ENV.fetch("GOVUK_ACCOUNT_OAUTH_PROVIDER_URI", Plek.find("account-manager"))
    @client_id = Rails.application.secrets.oauth_client_id
    @secret = Rails.application.secrets.oauth_client_secret

    if Rails.application.secrets.oauth_client_private_key.present?
      @private_key = OpenSSL::PKey::RSA.new Rails.application.secrets.oauth_client_private_key
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

    unless OidcUser.where(sub: tokens[:id_token].sub).exists?
      response = userinfo(access_token: tokens[:access_token], refresh_token: tokens[:refresh_token])
      OidcUser.find_or_create_by_sub!(tokens[:id_token].sub, legacy_sub: response.dig(:result, "govuk-account"))
      tokens.merge!(
        access_token: response.fetch(:access_token),
        refresh_token: response[:refresh_token],
      )
    end

    tokens.merge(
      mfa: tokens.fetch(:id_token).raw_attributes["vot"] == "Cl.Cm",
    )
  end

  def tokens!(oidc_nonce: nil)
    access_token =
      if use_client_private_key_auth?
        client.access_token!(
          client_id: client_id,
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

    response = access_token.token_response

    if oidc_nonce
      id_token_jwt = access_token.id_token
      id_token = OpenIDConnect::ResponseObject::IdToken.decode id_token_jwt, discover.jwks
      id_token.verify! client_id: client_id, issuer: discover.issuer, nonce: oidc_nonce
    end

    {
      access_token: response[:access_token],
      refresh_token: response[:refresh_token],
      id_token_jwt: id_token_jwt,
      id_token: id_token,
    }.compact
  rescue Rack::OAuth2::Client::Error
    raise OAuthFailure
  end

  def userinfo(access_token:, refresh_token:)
    response = time_and_return "userinfo" do
      oauth_request(
        access_token: access_token,
        refresh_token: refresh_token,
        method: :get,
        uri: userinfo_endpoint,
      )
    end

    begin
      response.merge(result: JSON.parse(response[:result].body))
    rescue JSON::ParserError
      raise OAuthFailure
    end
  end

private

  class RetryableOAuthFailure < StandardError; end

  OK_STATUSES = [200, 204, 404, 410].freeze
  MAX_OAUTH_RETRIES = 1

  def oauth_request(access_token:, refresh_token:, method:, uri:, arg: nil)
    args = [uri, arg].compact
    retries = 0

    begin
      response = Rack::OAuth2::AccessToken::Bearer.new(access_token: access_token).public_send(method, *args)
      raise RetryableOAuthFailure unless OK_STATUSES.include? response.status

      {
        access_token: access_token,
        refresh_token: refresh_token,
        result: response,
      }
    rescue RetryableOAuthFailure
      raise OAuthFailure unless retries < MAX_OAUTH_RETRIES
      raise OAuthFailure unless refresh_token

      access_token, refresh_token = refresh_client_tokens(refresh_token)

      retries += 1
      retry
    rescue Errno::ECONNRESET, OpenSSL::SSL::SSLError
      raise OAuthFailure unless retries < MAX_OAUTH_RETRIES

      retries += 1
      retry
    end
  rescue AttrRequired::AttrMissing, Rack::OAuth2::Client::Error, URI::InvalidURIError
    raise OAuthFailure
  end

  def refresh_client_tokens(refresh_token)
    client.refresh_token = refresh_token
    refreshed = client.access_token!
    [refreshed.token_response[:access_token], refreshed.token_response[:refresh_token]]
  end

  def redirect_uri
    host = Rails.env.production? ? ENV["GOVUK_WEBSITE_ROOT"] : Plek.find("frontend")
    "#{host}/sign-in/callback"
  end

  def client
    @client ||=
      begin
        client_options = {
          identifier: client_id,
          redirect_uri: redirect_uri,
          authorization_endpoint: authorization_endpoint,
          token_endpoint: token_endpoint,
          userinfo_endpoint: userinfo_endpoint,
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
end
