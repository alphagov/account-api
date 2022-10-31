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

    it "passes 'Cl' and 'Cl.Cm' to the auth service" do
      get sign_in_path
      expect(JSON.parse(response.body)["auth_uri"]).to include(Rack::Utils.escape('"Cl"'))
      expect(JSON.parse(response.body)["auth_uri"]).to include(Rack::Utils.escape('"Cl.Cm"'))
    end

    context "when mfa: false is given" do
      it "passes 'Cl' and 'Cl.Cm' to the auth service" do
        get sign_in_path, params: { mfa: false }
        expect(JSON.parse(response.body)["auth_uri"]).to include(Rack::Utils.escape('"Cl"'))
        expect(JSON.parse(response.body)["auth_uri"]).to include(Rack::Utils.escape('"Cl.Cm"'))
      end
    end

    context "when mfa: true is given" do
      it "passes 'Cl.Cm', but not 'Cl', to the auth service" do
        get sign_in_path, params: { mfa: true }
        expect(JSON.parse(response.body)["auth_uri"]).not_to include(Rack::Utils.escape('"Cl"'))
        expect(JSON.parse(response.body)["auth_uri"]).to include(Rack::Utils.escape('"Cl.Cm"'))
      end
    end
  end

  describe "/callback" do
    let!(:auth_request) { AuthRequest.create!(oauth_state: "foo", oidc_nonce: "bar", redirect_path: "/some-path") }

    it "fetches the tokens" do
      stub_userinfo
      post callback_path, headers: headers, params: { state: auth_request.to_oauth_state, code: "12345" }.to_json
      expect(response).to be_successful
      expect(JSON.parse(response.body)).to include("govuk_account_session", "redirect_path" => auth_request.redirect_path)
    end

    context "when cacheable attributes are missing" do
      let!(:user) { FactoryBot.create(:oidc_user, sub: "user-id", email: nil, email_verified: nil) }

      it "fetches them from userinfo" do
        stub = stub_userinfo(email: "email@example.com", email_verified: true)
        post callback_path, headers: headers, params: { state: auth_request.to_oauth_state, code: "12345" }.to_json
        expect(response).to be_successful
        expect(stub).to have_been_made
        expect(user.reload.email).to eq("email@example.com")
        expect(user.reload.email_verified).to be(true)
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

    def stub_userinfo(attributes = {})
      stub_request(:get, "http://openid-provider/userinfo-endpoint")
        .with(headers: { Authorization: "Bearer access-token" })
        .to_return(status: 200, body: attributes.to_json)
    end
  end

  describe "/end-session" do
    it "returns the end_session_endpoint for the identity provider" do
      get end_session_path, headers: headers
      expect(response).to be_successful
      expect(JSON.parse(response.body)["end_session_uri"]).to eq("http://openid-provider/end-session-endpoint")
    end

    context "when a session is given" do
      let(:headers) { { "Content-Type" => "application/json", "GOVUK-Account-Session" => session_identifier.serialise } }
      let(:session_identifier) { placeholder_govuk_account_session_object(id_token:) }
      let(:id_token) { "id-token" }

      it "includes an id_token_hint" do
        get end_session_path, headers: headers
        expect(response).to be_successful
        expect(JSON.parse(response.body)["end_session_uri"]).to eq("http://openid-provider/end-session-endpoint?id_token_hint=#{id_token}")
      end

      context "when there is no ID token in the session" do
        let(:id_token) { nil }

        it "does not include an id_token_hint" do
          get end_session_path, headers: headers
          expect(response).to be_successful
          expect(JSON.parse(response.body)["end_session_uri"]).to eq("http://openid-provider/end-session-endpoint")
        end
      end
    end
  end
end
