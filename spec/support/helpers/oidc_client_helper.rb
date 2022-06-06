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

  def stub_token_response(vot: "Cl")
    token_response = {
      access_token: "access-token",
      id_token_jwt: "id-token",
      id_token: instance_double(
        "OpenIDConnect::ResponseObject::IdToken",
        iss: "http://openid-provider",
        sub: "user-id",
        aud: "oauth-client",
        exp: 300,
        iat: 0,
        raw_attributes: { "vot" => vot },
      ),
    }.compact

    # rubocop:disable RSpec/AnyInstance
    allow_any_instance_of(OidcClient).to receive(:tokens!).and_return(token_response)
    # rubocop:enable RSpec/AnyInstance
  end

  def stub_userinfo(attributes = {})
    stub_request(:get, "http://openid-provider/userinfo-endpoint")
      .to_return(status: 200, body: attributes.to_json)
  end

  def stub_jwk_discovery
    # rubocop:disable RSpec/AnyInstance
    allow_any_instance_of(OpenIDConnect::Discovery::Provider::Config::Response).to receive(:jwks).and_return(jwt_signing_key)
    # rubocop:enable RSpec/AnyInstance
  end

  def stub_issuer
    # rubocop:disable RSpec/AnyInstance
    allow_any_instance_of(OpenIDConnect::Discovery::Provider::Config::Response).to receive(:issuer).and_return(iss)
    # rubocop:enable RSpec/AnyInstance
  end
end

RSpec.configuration.send :include, OidcClientHelper
