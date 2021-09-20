require "gds_api/test_helpers/content_store"

RSpec.describe "User information endpoint" do
  include GdsApi::TestHelpers::ContentStore

  before do
    stub_oidc_discovery
    stub_userinfo(attributes)
  end

  let(:session_identifier) { placeholder_govuk_account_session_object(mfa: mfa) }
  let(:headers) { { "Content-Type" => "application/json", "GOVUK-Account-Session" => session_identifier&.serialise }.compact }
  let(:mfa) { false }

  let(:attributes) do
    {
      email: "email@example.com",
      email_verified: true,
      has_unconfirmed_email: false,
    }
  end

  let(:response_body) { JSON.parse(response.body) }

  it "returns 200 OK" do
    get "/api/user", headers: headers
    expect(response).to be_successful
  end

  it "returns the user's ID" do
    get "/api/user", headers: headers
    expect(response_body["id"]).to eq(session_identifier.user.id.to_s)
  end

  it "returns whether the user has done MFA" do
    get "/api/user", headers: headers
    expect(response_body["mfa"]).to eq(session_identifier.mfa?)
  end

  it "returns the user's email attributes" do
    get "/api/user", headers: headers
    expect(response_body["email"]).to eq(attributes[:email])
    expect(response_body["email_verified"]).to eq(attributes[:email_verified])
  end

  describe "services.transition_checker" do
    let(:service_state) { response_body.dig("services", "transition_checker") }

    it "returns 'no'" do
      get "/api/user", headers: headers
      expect(service_state).to eq("no")
    end

    context "when the user has used the checker" do
      before { session_identifier.user.update!(transition_checker_state: "state") }

      it "returns 'yes_but_must_reauthenticate'" do
        get "/api/user", headers: headers
        expect(service_state).to eq("yes_but_must_reauthenticate")
      end

      context "when the user is logged in with MFA" do
        let(:mfa) { true }

        it "returns 'yes'" do
          get "/api/user", headers: headers
          expect(service_state).to eq("yes")
        end
      end
    end
  end

  describe "services.saved_pages" do
    let(:service_state) { response_body.dig("services", "saved_pages") }

    it "returns 'no'" do
      get "/api/user", headers: headers
      expect(service_state).to eq("no")
    end

    context "when the user has saved pages" do
      before { stub_user_has_saved_pages }

      it "returns 'yes'" do
        get "/api/user", headers: headers
        expect(service_state).to eq("yes")
      end
    end
  end

  context "when the user is not logged in" do
    let(:session_identifier) { nil }

    it "returns a 401" do
      get "/api/user", headers: headers
      expect(response).to have_http_status(:unauthorized)
    end
  end

  def stub_user_has_saved_pages
    page_path = "/page-path"
    stub_content_store_has_item(page_path, content_item_for_base_path(page_path).merge("content_id" => SecureRandom.uuid))
    put saved_page_path(page_path: page_path), headers: headers
  end
end
