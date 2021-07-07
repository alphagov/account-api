require "openid_connect"

class OidcClient
  class OAuthFailure < RuntimeError; end

  DEFAULT_SCOPES = %i[email transition_checker openid].freeze

  attr_reader :client_id,
              :provider_uri

  delegate :authorization_endpoint,
           :token_endpoint,
           :userinfo_endpoint,
           :end_session_endpoint,
           to: :discover

  def initialize
    @provider_uri = Plek.find("account-manager")
    @client_id = Rails.application.secrets.oauth_client_id
    @secret = Rails.application.secrets.oauth_client_secret
  end

  def auth_uri(auth_request, level_of_authentication)
    client.authorization_uri(
      scope: DEFAULT_SCOPES + [level_of_authentication],
      state: auth_request.to_oauth_state,
      nonce: auth_request.oidc_nonce,
    )
  end

  def callback(auth_request, code)
    client.authorization_code = code

    time_and_return "tokens" do
      tokens!(oidc_nonce: auth_request.oidc_nonce)
    end
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

  def get_ephemeral_state(access_token:, refresh_token:)
    response = time_and_return "get_ephemeral_state" do
      oauth_request(
        access_token: access_token,
        refresh_token: refresh_token,
        method: :get,
        uri: ephemeral_state_uri,
      )
    end

    begin
      response.merge(result: JSON.parse(response[:result].body))
    rescue JSON::ParserError
      response.merge(result: {})
    end
  end

  def get_attribute(attribute:, access_token:, refresh_token: nil)
    response = time_and_return "get_attribute" do
      oauth_request(
        access_token: access_token,
        refresh_token: refresh_token,
        method: :get,
        uri: attribute_uri(attribute),
      )
    end

    body = response[:result].body
    if response[:result].status != 200 || body.empty?
      response.merge(result: nil)
    else
      response.merge(result: JSON.parse(body)["claim_value"])
    end
  end

  def bulk_set_attributes(attributes:, access_token:, refresh_token: nil)
    time_and_return "bulk_set_attributes" do
      oauth_request(
        access_token: access_token,
        refresh_token: refresh_token,
        method: :post,
        uri: bulk_attribute_uri,
        arg: attributes.transform_keys { |key| "attributes[#{key}]" }.transform_values(&:to_json),
      )
    end
  end

  def get_transition_checker_email_subscription(access_token:, refresh_token: nil)
    response = time_and_return "get_transition_checker_email_subscription" do
      oauth_request(
        access_token: access_token,
        refresh_token: refresh_token,
        method: :get,
        uri: transition_checker_email_subscription_uri,
      )
    end

    body = response[:result].body
    if response[:result].status != 200 || body.empty?
      response.merge(result: nil)
    else
      response.merge(result: JSON.parse(body))
    end
  end

  def set_transition_checker_email_subscription(slug:, access_token:, refresh_token: nil)
    response = time_and_return "set_transition_checker_email_subscription" do
      oauth_request(
        access_token: access_token,
        refresh_token: refresh_token,
        method: :post,
        uri: transition_checker_email_subscription_uri,
        arg: { topic_slug: slug },
      )
    end

    body = response[:result].body
    if response[:result].status != 200 || body.empty?
      response.merge(result: nil)
    else
      response.merge(result: JSON.parse(body))
    end
  end

  def migrate_transition_checker_email_subscription(access_token:, refresh_token: nil)
    time_and_return "migrate_transition_checker_email_subscription" do
      oauth_request(
        access_token: access_token,
        refresh_token: refresh_token,
        method: :delete,
        uri: transition_checker_email_subscription_uri,
      )
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

  def ephemeral_state_uri
    URI.parse(provider_uri).tap do |u|
      u.path = "/api/v1/ephemeral-state"
    end
  end

  def attribute_uri(attribute)
    URI.parse(userinfo_endpoint).tap do |u|
      u.path = "/v1/attributes/#{attribute}"
    end
  end

  def bulk_attribute_uri
    URI.parse(userinfo_endpoint).tap do |u|
      u.path = "/v1/attributes"
    end
  end

  def transition_checker_email_subscription_uri
    URI.parse(provider_uri).tap do |u|
      u.path = "/api/v1/transition-checker/email-subscription"
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
