require "gds_api/test_helpers/account_api"
require "gds_api/test_helpers/email_alert_api"
require "govuk_personalisation/test_helpers/requests"

RSpec.describe "Personalisation - Check Email Subscription" do
  include GdsApi::TestHelpers::AccountApi
  include GdsApi::TestHelpers::EmailAlertApi
  include GovukPersonalisation::TestHelpers::Requests

  describe "GET /api/personalisation/check-email-subscription" do
    let(:topic_slug) { "topic_slug" }

    it "returns 401" do
      get check_email_subscription_path(topic_slug: topic_slug)
      expect(response).to have_http_status(:unauthorized)
    end

    context "with an autenticated session" do
      let(:subscription_status_details) do
        {
          "topic_slug": topic_slug,
          "active": subscription_active,
        }.to_json
      end

      let(:subscription_active) { false }

      let(:oidc_user) { FactoryBot.create(:oidc_user) }
      let(:sub) { oidc_user.sub }
      let(:subscriber_id) { 42 }
      let(:subscriptions) do
        [
          {
            "id" => subscriber_id,
            "created_at" => "2019-09-16 02:08:08 01:00",
            "subscriber_list" => { "title" => "Some thing", "slug" => topic_slug },
          },
        ]
      end
      let(:session_identifier) { placeholder_govuk_account_session_object(user_id: sub, mfa: false) }
      let(:headers) { { "Content-Type" => "application/json", "GOVUK-Account-Session" => session_identifier&.serialise }.compact }

      it "logs the user out if the session is invalid" do
        get check_email_subscription_path, headers: { "GOVUK-Account-Session" => "not-a-base64-string" }
        expect(response).to have_http_status(:unauthorized)
      end

      context "when the user has linked their notifications account" do
        before { stub_email_alert_api_find_subscriber_by_govuk_account(oidc_user.id, subscriber_id, "test@example.com") }

        context "when the topic_slug matches an active subscription" do
          before { stub_email_alert_api_has_subscriber_subscriptions(subscriber_id, "test@example.com", subscriptions: subscriptions) }

          let(:subscription_active) { true }

          it "returns subscription status details as active" do
            get check_email_subscription_path(topic_slug: topic_slug), headers: headers
            expect(response.body).to eq(subscription_status_details)
          end
        end

        context "when the topic_slug does not match an active subscription" do
          before { stub_email_alert_api_does_not_have_subscriber_subscriptions(subscriber_id) }

          it "returns subscription status details as not active" do
            get check_email_subscription_path(topic_slug: topic_slug), headers: headers
            expect(response.body).to eq(subscription_status_details)
          end
        end
      end

      context "when the user has not linked their notifications account" do
        before { stub_email_alert_api_find_subscriber_by_govuk_account_no_subscriber(oidc_user.id) }

        it "returns subscription status details as not active" do
          get check_email_subscription_path(topic_slug: topic_slug), headers: headers
          expect(response.body).to eq(subscription_status_details)
        end
      end
    end
  end
end
