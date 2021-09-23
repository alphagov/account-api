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
      scope: %i[openid email],
      state: auth_request.to_oauth_state,
      nonce: auth_request.oidc_nonce,
    ) + "&vtr=#{vtr}"
  end

  def callback(auth_request, code)
    client.authorization_code = code

    tokens = time_and_return "tokens" do
      tokens!(oidc_nonce: auth_request.oidc_nonce)
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

  OK_STATUSES = [200, 204, 404, 410].freeze

  def oauth_request(access_token:, refresh_token:, method:, uri:, arg: nil)
    access_token_str = access_token
    refresh_token_str = refresh_token

    args = [uri, arg].compact

    response = Rack::OAuth2::AccessToken::Bearer.new(access_token: access_token_str).public_send(method, *args)

    unless OK_STATUSES.include? response.status
      raise OAuthFailure unless refresh_token

      client.refresh_token = refresh_token
      access_token = client.access_token!

      response = access_token.public_send(method, *args)
      raise OAuthFailure unless OK_STATUSES.include? response.status

      access_token_str = access_token.token_response[:access_token]
      refresh_token_str = access_token.token_response[:refresh_token]
    end

    {
      access_token: access_token_str,
      refresh_token: refresh_token_str,
      result: response,
    }
  rescue AttrRequired::AttrMissing, Rack::OAuth2::Client::Error, URI::InvalidURIError
    raise OAuthFailure
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
