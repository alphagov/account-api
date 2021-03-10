RSpec.describe AuthenticationController do
  before do
    discovery_response = instance_double(
      "OpenIDConnect::Discovery::Provider::Config::Response",
      authorization_endpoint: "http://openid-provider/authorization-endpoint",
      token_endpoint: "http://openid-provider/token-endpoint",
      userinfo_endpoint: "http://openid-provider/userinfo-endpoint",
      end_session_endpoint: "http://openid-provider/end-session-endpoint",
    )

    # rubocop:disable RSpec/AnyInstance
    allow_any_instance_of(OidcClient).to receive(:discover).and_return(discovery_response)
    allow_any_instance_of(OidcClient).to receive(:tokens!).and_return({ access_token: "access-token", refresh_token: "refresh-token" })
    # rubocop:enable RSpec/AnyInstance
  end

  describe "/sign-in" do
    it "creates an AuthRequest to persist the attributes" do
      expect { get sign_in_path }.to change(AuthRequest, :count)
      expect(response).to be_successful

      auth_request = AuthRequest.last

      expect(JSON.parse(response.body)["state"]).to eq(auth_request.to_oauth_state)

      auth_uri = JSON.parse(response.body)["auth_uri"]

      expect(auth_uri).to include("nonce=#{auth_request.oidc_nonce}")
      expect(auth_uri).to include("state=#{auth_request.to_oauth_state.sub(':', '%3A')}")
    end

    it "uses a provided state_id" do
      get sign_in_path(state_id: "hello-world")
      expect(AuthRequest.last.oauth_state).to eq("hello-world")
    end

    it "uses a provided redirect_path" do
      get sign_in_path(redirect_path: "/hello-world")
      expect(AuthRequest.last.redirect_path).to eq("/hello-world")
    end
  end

  describe "/callback" do
    let!(:auth_request) { AuthRequest.create!(oauth_state: "foo", oidc_nonce: "bar", redirect_path: "/some-path") }

    it "fetches the tokens & GA client ID" do
      stub_request(:get, Plek.find("account-manager") + "/api/v1/ephemeral-state")
        .with(headers: { "Authorization" => "Bearer access-token" })
        .to_return(status: 200, body: { _ga: "ga-client-id" }.to_json)

      post callback_path(state: auth_request.to_oauth_state, code: "12345")
      expect(response).to be_successful
      expect(JSON.parse(response.body)).to include("govuk_account_session", "redirect_path" => auth_request.redirect_path, "ga_client_id" => "ga-client-id")
    end

    it "returns a 401 if there is no matching AuthRequest" do
      post callback_path(state: "something-else")
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns a 401 if the auth code is rejected" do
      # rubocop:disable RSpec/AnyInstance
      allow_any_instance_of(OidcClient).to receive(:tokens!).and_raise(OidcClient::OAuthFailure)
      # rubocop:enable RSpec/AnyInstance

      post callback_path(state: auth_request.to_oauth_state, code: "12345")
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
