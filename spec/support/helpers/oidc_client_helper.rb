module OidcClientHelper
  def stub_oidc_discovery
    discovery_response = {
      authorization_endpoint: "http://openid-provider/authorization-endpoint",
      token_endpoint: "http://openid-provider/token-endpoint",
      userinfo_endpoint: "http://openid-provider/userinfo-endpoint",
      end_session_endpoint: "http://openid-provider/end-session-endpoint",
    }

    # rubocop:disable RSpec/AnyInstance
    allow_any_instance_of(OidcClient).to receive(:cached_discover_response).and_return(discovery_response)
    # rubocop:enable RSpec/AnyInstance
  end

  def stub_token_response
    token_response = {
      access_token: "access-token",
      refresh_token: "refresh-token",
      id_token: instance_double(
        "OpenIDConnect::ResponseObject::IdToken",
        iss: "http://openid-provider",
        sub: "user-id",
        aud: "oauth-client",
        exp: 300,
        iat: 0,
      ),
    }

    # rubocop:disable RSpec/AnyInstance
    allow_any_instance_of(OidcClient).to receive(:tokens!).and_return(token_response)
    # rubocop:enable RSpec/AnyInstance
  end

  def stub_remote_attribute_request(name:, value: nil, status: nil)
    status ||= value.nil? ? 404 : 200
    stub_request(:get, "http://openid-provider/v1/attributes/#{name}")
      .to_return(status: status, body: { claim_value: value }.compact.to_json)
  end

  def stub_remote_attribute_requests(names_and_values = {})
    names_and_values.each do |name, value|
      stub_remote_attribute_request(name: name, value: value)
    end
  end
end

RSpec.configuration.send :include, OidcClientHelper
