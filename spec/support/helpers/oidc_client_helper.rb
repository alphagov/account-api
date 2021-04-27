module OidcClientHelper
  def stub_oidc_discovery
    discovery_response = instance_double(
      "OpenIDConnect::Discovery::Provider::Config::Response",
      authorization_endpoint: "http://openid-provider/authorization-endpoint",
      token_endpoint: "http://openid-provider/token-endpoint",
      userinfo_endpoint: "http://openid-provider/userinfo-endpoint",
      end_session_endpoint: "http://openid-provider/end-session-endpoint",
    )

    # rubocop:disable RSpec/AnyInstance
    allow_any_instance_of(OidcClient).to receive(:discover).and_return(discovery_response)
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

  def stub_oidc_client(client = nil)
    oidc_client = instance_double("OpenIDConnect::Client")

    if client
      allow(client).to receive(:client).and_return(oidc_client)
    else
      # rubocop:disable RSpec/AnyInstance
      allow_any_instance_of(OidcClient).to receive(:client).and_return(oidc_client)
      # rubocop:enable RSpec/AnyInstance
    end

    oidc_client
  end

  def allow_token_refresh(client)
    new_access_token = Rack::OAuth2::AccessToken::Bearer.new(
      access_token: "new-access-token",
      refresh_token: "new-refresh-token",
    )

    allow(client).to receive(:"refresh_token=").with("refresh-token")
    allow(client).to receive(:access_token!).and_return(new_access_token)
  end
end

RSpec.configuration.send :include, OidcClientHelper
