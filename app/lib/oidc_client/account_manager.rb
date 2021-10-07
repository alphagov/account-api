class OidcClient::AccountManager < OidcClient
  def auth_uri(auth_request, mfa: false)
    level_of_authentication = mfa ? "level1" : "level0"
    client.authorization_uri(
      scope: [:email, :openid, level_of_authentication],
      state: auth_request.to_oauth_state,
      nonce: auth_request.oidc_nonce,
    )
  end

  def callback(auth_request, code)
    client.authorization_code = code

    tokens = time_and_return "tokens" do
      tokens!(oidc_nonce: auth_request.oidc_nonce)
    end

    response = get_ephemeral_state(
      access_token: tokens[:access_token],
      refresh_token: tokens[:refresh_token],
    )

    tokens.merge(
      access_token: response.fetch(:access_token),
      refresh_token: response.fetch(:refresh_token),
      mfa: response.fetch(:result).fetch("level_of_authentication") == "level1",
      ga_session_id: response.fetch(:result)["_ga"],
      cookie_consent: response.fetch(:result)["cookie_consent"],
    )
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

private

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
end
