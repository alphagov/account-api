require "openid_connect"

class OidcClient
  class OAuthFailure < RuntimeError; end

  DEFAULT_SCOPES = %i[transition_checker openid].freeze

  attr_reader :client_id,
              :provider_uri

  delegate :authorization_endpoint,
           :token_endpoint,
           :userinfo_endpoint,
           :end_session_endpoint,
           to: :discover

  def initialize(provider_uri: nil, client_id: nil, secret: nil)
    @provider_uri = provider_uri || Plek.find("account-manager")
    @client_id = client_id || ENV.fetch("GOVUK_ACCOUNT_OAUTH_CLIENT_ID")
    @secret = secret || ENV.fetch("GOVUK_ACCOUNT_OAUTH_CLIENT_SECRET")
  end

  def auth_uri(auth_request)
    client.authorization_uri(
      scope: DEFAULT_SCOPES,
      state: auth_request.to_oauth_state,
      nonce: auth_request.oidc_nonce,
    )
  end

  def callback(auth_request, code)
    client.authorization_code = code

    tokens!(oidc_nonce: auth_request.oidc_nonce)
  end

  def tokens!(oidc_nonce: nil)
    access_token = client.access_token!
    response = access_token.token_response

    if oidc_nonce
      id_token = OpenIDConnect::ResponseObject::IdToken.decode access_token.id_token, discover.jwks
      id_token.verify! client_id: client_id, issuer: discover.issuer, nonce: oidc_nonce
    end

    {
      access_token: response[:access_token],
      refresh_token: response[:refresh_token],
      id_token: id_token,
    }.compact
  rescue Rack::OAuth2::Client::Error
    raise OAuthFailure
  end

  def get_ephemeral_state(access_token:, refresh_token:)
    response = oauth_request(
      access_token: access_token,
      refresh_token: refresh_token,
      method: :get,
      uri: ephemeral_state_uri,
    )

    begin
      response.merge(result: JSON.parse(response[:result].body))
    rescue JSON::ParserError
      response.merge(result: {})
    end
  end

protected

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
    host = Rails.env.production? ? ENV["GOVUK_WEBSITE_ROOT"] : Plek.find("finder-frontend")
    host + "/transition-check/login/callback"
  end

  def ephemeral_state_uri
    URI.parse(provider_uri).tap do |u|
      u.path = "/api/v1/ephemeral-state"
    end
  end

  def client
    @client ||= OpenIDConnect::Client.new(
      identifier: client_id,
      secret: @secret,
      redirect_uri: redirect_uri,
      authorization_endpoint: authorization_endpoint,
      token_endpoint: token_endpoint,
      userinfo_endpoint: userinfo_endpoint,
    )
  end

  def discover
    @discover ||= OpenIDConnect::Discovery::Provider::Config.discover! provider_uri
  end
end
