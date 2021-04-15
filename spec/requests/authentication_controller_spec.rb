RSpec.describe AuthenticationController do
  before do
    stub_oidc_discovery

    # rubocop:disable RSpec/AnyInstance
    allow_any_instance_of(OidcClient).to receive(:tokens!).and_return({ access_token: "access-token", refresh_token: "refresh-token" })
    # rubocop:enable RSpec/AnyInstance
  end

  let(:headers) { { "Content-Type" => "application/json" } }

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
      get sign_in_path, params: { state_id: "hello-world" }
      expect(AuthRequest.last.oauth_state).to eq("hello-world")
    end

    it "uses a provided redirect_path" do
      get sign_in_path, params: { redirect_path: "/hello-world" }
      expect(AuthRequest.last.redirect_path).to eq("/hello-world")
    end

    it "deletes old expired AuthRequests" do
      auth_request_id = AuthRequest.create!(oauth_state: "foo", oidc_nonce: "bar", redirect_path: "/some-path", created_at: 1.day.ago).id
      get sign_in_path
      expect(AuthRequest.exists?(auth_request_id)).to be(false)
    end
  end

  describe "/callback" do
    let!(:auth_request) { AuthRequest.create!(oauth_state: "foo", oidc_nonce: "bar", redirect_path: "/some-path") }

    it "fetches the tokens & ephemeral state" do
      stub_request(:get, Plek.find("account-manager") + "/api/v1/ephemeral-state")
        .with(headers: { "Authorization" => "Bearer access-token" })
        .to_return(status: 200, body: { _ga: "ga-client-id", level_of_authentication: "level42" }.to_json)

      post callback_path, headers: headers, params: { state: auth_request.to_oauth_state, code: "12345" }.to_json
      expect(response).to be_successful
      expect(JSON.parse(response.body)).to include("govuk_account_session", "redirect_path" => auth_request.redirect_path, "ga_client_id" => "ga-client-id")
    end

    it "returns a 401 if there is no matching AuthRequest" do
      post callback_path, headers: headers, params: { state: "something-else" }.to_json
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns a 401 if the auth code is rejected" do
      # rubocop:disable RSpec/AnyInstance
      allow_any_instance_of(OidcClient).to receive(:tokens!).and_raise(OidcClient::OAuthFailure)
      # rubocop:enable RSpec/AnyInstance

      post callback_path, headers: headers, params: { state: auth_request.to_oauth_state, code: "12345" }.to_json
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "/state" do
    it "submits a JWT to the account manager" do
      stub_request(:post, Plek.find("account-manager") + "/api/v1/jwt")
        .with(headers: { "Authorization" => "Bearer access-token" })
        .to_return(status: 200, body: { id: "jwt-id" }.to_json)

      post state_path, headers: headers, params: { attributes: { key: "value" } }.to_json
      expect(response).to be_successful
      expect(JSON.parse(response.body)).to include("state_id" => "jwt-id")
    end
  end
end
