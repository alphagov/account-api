require "gds_api/test_helpers/email_alert_api"

RSpec.describe "Logout Notice Invalidation" do
  include ActiveSupport::Testing::TimeHelpers
  let(:sub) { "user-id" }
  let(:redis_state) { Redis.new.get("logout-notice/#{sub}") }
  let(:redis_formatted_time) { Time.zone.now.strftime("%F %T %z") }
  let(:headers) { { "Content-Type" => "application/json" } }

  before do
    freeze_time
    Redis.new.flushdb
  end

  context "when a logout notice exists for sub" do
    before { Redis.new.set("logout-notice/#{sub}", Time.zone.now) }

    it "invalidates the notice on a sucessful callback_path request" do
      stub_userinfo
      stub_oidc_discovery
      stub_token_response
      auth_request = AuthRequest.create!(oauth_state: "foo", oidc_nonce: "bar", redirect_path: "/some-path")
      expect {
        post callback_path,
             headers: headers,
             params: { state: auth_request.to_oauth_state, code: "12345" }.to_json
      }.to change {
        Redis.new.get("logout-notice/#{sub}")
      }.from(redis_formatted_time).to(nil)
    end

    it "invalidates the notice a successful call to destroy a user" do
      user = FactoryBot.create(:oidc_user, sub: sub, legacy_sub: nil)
      stub_request(:get, "#{GdsApi::TestHelpers::EmailAlertApi::EMAIL_ALERT_API_ENDPOINT}/subscribers/govuk-account/#{user.id}").to_return(status: 404)
      expect {
        delete oidc_user_path(subject_identifier: sub)
      }.to change {
        Redis.new.get("logout-notice/#{sub}")
      }.from(redis_formatted_time).to(nil)
    end
  end
end
