require "gds_api/test_helpers/content_store"

RSpec.describe "User information endpoint" do
  include GdsApi::TestHelpers::ContentStore

  before do
    session_identifier&.set_attributes(attributes)
  end

  let(:session_identifier) { placeholder_govuk_account_session_object(mfa:) }
  let(:headers) { { "Content-Type" => "application/json", "GOVUK-Account-Session" => session_identifier&.serialise }.compact }
  let(:mfa) { false }

  let(:attributes) do
    {
      email: "email@example.com",
      email_verified: true,
    }
  end

  let(:response_body) { JSON.parse(response.body) }

  it "returns 200 OK" do
    get("/api/user", headers:)
    expect(response).to be_successful
  end

  it "returns the user's ID" do
    get("/api/user", headers:)
    expect(response_body["id"]).to eq(session_identifier.user.id.to_s)
  end

  it "returns whether the user has done MFA" do
    get("/api/user", headers:)
    expect(response_body["mfa"]).to eq(session_identifier.mfa?)
  end

  it "returns the user's email attributes" do
    get("/api/user", headers:)
    expect(response_body["email"]).to eq(attributes[:email])
    expect(response_body["email_verified"]).to eq(attributes[:email_verified])
  end

  context "when the user is not logged in" do
    let(:session_identifier) { nil }

    it "returns a 401" do
      get("/api/user", headers:)
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
