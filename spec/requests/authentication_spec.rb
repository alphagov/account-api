RSpec.describe "Authentication" do
  before do
    stub_oidc_discovery
    stub_token_response
  end

  let(:headers) { { "Content-Type" => "application/json" } }

  describe "/sign-in" do
    it "creates an AuthRequest to persist the attributes" do
      expect { get sign_in_path }.to change(AuthRequest, :count).by(1)
      expect(response).to be_successful

      auth_request = AuthRequest.last

      expect(JSON.parse(response.body)["state"]).to eq(auth_request.to_oauth_state)

      auth_uri = JSON.parse(response.body)["auth_uri"]

      expect(auth_uri).to include("nonce=#{auth_request.oidc_nonce}")
      expect(auth_uri).to include("state=#{auth_request.to_oauth_state.sub(':', '%3A')}")
    end

    it "uses a provided redirect_path" do
      get sign_in_path, params: { redirect_path: "/transition-check/results?c[]=import-wombats&c[]=practice-wizardry" }
      expect(AuthRequest.last.redirect_path).to eq("/transition-check/results?c[]=import-wombats&c[]=practice-wizardry")
    end
  end

  describe "/callback" do
    let!(:auth_request) { AuthRequest.create!(oauth_state: "foo", oidc_nonce: "bar", redirect_path: "/some-path") }

    it "fetches the tokens" do
      post callback_path, headers: headers, params: { state: auth_request.to_oauth_state, code: "12345" }.to_json
      expect(response).to be_successful
      expect(JSON.parse(response.body)).to include("govuk_account_session", "redirect_path" => auth_request.redirect_path)
    end

    context "when using the account manager" do
      before do
        allow(Rails.application.secrets).to receive(:oauth_client_private_key).and_return(nil)

        stub_request(:get, "#{Plek.find('account-manager')}/api/v1/ephemeral-state")
          .with(headers: { "Authorization" => "Bearer access-token" })
          .to_return(status: 200, body: { _ga: "ga-client-id", level_of_authentication: "level42", cookie_consent: true }.to_json)
      end

      it "fetches the tokens & ephemeral state" do
        post callback_path, headers: headers, params: { state: auth_request.to_oauth_state, code: "12345" }.to_json
        expect(response).to be_successful
        expect(JSON.parse(response.body)).to include("govuk_account_session", "redirect_path" => auth_request.redirect_path, "ga_client_id" => "ga-client-id", "cookie_consent" => true)
      end
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
end
