RSpec.describe "Matching users by email address" do
  let(:session_identifier) { nil }
  let(:session_header_value) { session_identifier&.serialise }
  let(:headers) { { "Content-Type" => "application/json", "GOVUK-Account-Session" => session_header_value }.compact }

  let(:email) { "no-such-email@example.com" }
  let(:params) { { email: } }

  it "returns 404 Not Found" do
    get "/api/user/match-by-email", params: params, headers: headers
    expect(response).to have_http_status(:not_found)
  end

  context "when a session is given" do
    let(:session_identifier) { placeholder_govuk_account_session_object }

    it "returns 404 Not Found" do
      get "/api/user/match-by-email", params: params, headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  context "when the address matches a user" do
    let!(:user) { FactoryBot.create(:oidc_user) }
    let(:email) { user.email }

    it "returns 200 OK" do
      get "/api/user/match-by-email", params: params, headers: headers
      expect(response).to be_successful
    end

    it "returns `match: false`" do
      get "/api/user/match-by-email", params: params, headers: headers
      expect(JSON.parse(response.body)).to eq({ "match" => false })
    end

    it "does a case-insensitive match of the address" do
      get "/api/user/match-by-email", params: { email: user.email.upcase }, headers: headers
      expect(response).to be_successful
    end

    context "when a session is given" do
      let(:session_identifier) { placeholder_govuk_account_session_object }

      it "returns `match: false`" do
        get "/api/user/match-by-email", params: params, headers: headers
        expect(JSON.parse(response.body)).to eq({ "match" => false })
      end

      context "when the session header value is invalid" do
        let(:session_header_value) { "." }

        it "treats it as nonexistent" do
          get "/api/user/match-by-email", params: params, headers: headers
          expect(JSON.parse(response.body)).to eq({ "match" => false })
        end
      end

      context "when the address matches the session" do
        before { session_identifier.user.update!(email:) }

        let(:email) { "user-from-session@example.com" }

        it "returns `match: true`" do
          get "/api/user/match-by-email", params: params, headers: headers
          expect(JSON.parse(response.body)).to eq({ "match" => true })
        end
      end
    end
  end
end
