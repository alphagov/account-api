require "gds_api/test_helpers/account_api"
require "gds_api/test_helpers/email_alert_api"
require "govuk_personalisation/test_helpers/requests"

RSpec.describe "Personalisation - Check Email Subscription" do
  include GdsApi::TestHelpers::AccountApi
  include GdsApi::TestHelpers::EmailAlertApi
  include GovukPersonalisation::TestHelpers::Requests

  describe "GET /api/personalisation/check-email-subscription" do
    let(:base_path) { nil }
    let(:topic_slug) { nil }
    let(:button_location) { nil }
    let(:params) { { base_path: base_path, topic_slug: topic_slug, button_location: button_location }.compact }

    let(:active) { false }

    let(:subscription_details) do
      {
        "base_path" => base_path,
        "topic_slug" => topic_slug,
        "active" => active,
      }.compact
    end

    it "returns 401" do
      get personalisation_check_email_subscription_path, params: params
      expect(response).to have_http_status(:unauthorized)
    end

    context "with an authenticated session" do
      let(:subscriptions) do
        [
          {
            "id" => 1,
            "created_at" => "2019-09-16 02:08:08 01:00",
            "subscriber_list" => {
              "id" => 2,
              "title" => "Some thing",
              "url" => list_url,
              "slug" => list_slug,
            }.compact,
          },
        ]
      end

      let(:list_url) { "/some/other/path" }
      let(:list_slug) { "some-other-slug" }

      let(:oidc_user) { FactoryBot.create(:oidc_user) }
      let(:sub) { oidc_user.sub }
      let(:subscriber_id) { 42 }
      let(:session_identifier) { placeholder_govuk_account_session_object(user_id: sub, mfa: false) }
      let(:headers) { { "Content-Type" => "application/json", "GOVUK-Account-Session" => session_identifier&.serialise }.compact }

      it "returns a 422" do
        get personalisation_check_email_subscription_path, params: params, headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
      end

      context "when the session is invalid" do
        let(:headers) { { "GOVUK-Account-Session" => "not-a-base64-string" } }

        it "logs the user out" do
          get personalisation_check_email_subscription_path, params: params, headers: headers
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context "when a base_path is passed" do
        let(:base_path) { "/foo" }
        let(:subscription_slug) { "foo" }

        context "when a topic_slug is also passed" do
          let(:topic_slug) { "topic_slug" }

          it "returns a 422" do
            get personalisation_check_email_subscription_path, params: params, headers: headers
            expect(response).to have_http_status(:unprocessable_entity)
          end
        end

        context "when the user has linked their notifications account" do
          before { stub_email_alert_api_find_subscriber_by_govuk_account(oidc_user.id, subscriber_id, "test@example.com") }

          context "when the user has active subscriptions" do
            before { stub_email_alert_api_has_subscriber_subscriptions(subscriber_id, "test@example.com", subscriptions: subscriptions) }

            it "returns subscription status details as not active" do
              get personalisation_check_email_subscription_path, params: params, headers: headers
              expect(JSON.parse(response.body)).to include(subscription_details)
            end

            it "includes the inactive-state button HTML" do
              get personalisation_check_email_subscription_path, params: params, headers: headers
              expect(JSON.parse(response.body)["button_html"]).to include("Get emails about this page")
            end

            context "when an active subscription has a matching url" do
              let(:list_url) { base_path }
              let(:active) { true }

              it "returns subscription status details as active" do
                get personalisation_check_email_subscription_path, params: params, headers: headers
                expect(JSON.parse(response.body)).to include(subscription_details)
              end

              it "includes the active-state button HTML" do
                get personalisation_check_email_subscription_path, params: params, headers: headers
                expect(JSON.parse(response.body)["button_html"]).to include("Stop getting emails about this page")
              end
            end
          end

          context "when the user does not have active subscriptions" do
            before { stub_email_alert_api_does_not_have_subscriber_subscriptions(subscriber_id) }

            it "returns subscription status details as not active" do
              get personalisation_check_email_subscription_path, params: params, headers: headers
              expect(JSON.parse(response.body)).to include(subscription_details)
            end

            it "includes the inactive-state button HTML" do
              get personalisation_check_email_subscription_path, params: params, headers: headers
              expect(JSON.parse(response.body)["button_html"]).to include("Get emails about this page")
            end

            context "when a button location is passed" do
              let(:button_location) { "top-of-page" }

              it "returns the location in the response" do
                get personalisation_check_email_subscription_path, params: params, headers: headers
                expect(JSON.parse(response.body)["button_location"]).to eq(button_location)
              end
            end
          end
        end

        context "when the user has not linked their notifications account" do
          before { stub_email_alert_api_find_subscriber_by_govuk_account_no_subscriber(oidc_user.id) }

          it "returns subscription status details as not active" do
            get personalisation_check_email_subscription_path, params: params, headers: headers
            expect(JSON.parse(response.body)).to include(subscription_details)
          end

          it "includes the inactive-state button HTML" do
            get personalisation_check_email_subscription_path, params: params, headers: headers
            expect(JSON.parse(response.body)["button_html"]).to include("Get emails about this page")
          end
        end
      end

      context "when a topic_slug is passed" do
        before { stub_email_alert_api_find_subscriber_by_govuk_account(oidc_user.id, subscriber_id, "test@example.com") }

        let(:topic_slug) { "topic_slug" }

        context "when the user has active subscriptions" do
          before { stub_email_alert_api_has_subscriber_subscriptions(subscriber_id, "test@example.com", subscriptions: subscriptions) }

          it "returns subscription status details as not active" do
            get personalisation_check_email_subscription_path, params: params, headers: headers
            expect(JSON.parse(response.body)).to include(subscription_details)
          end

          it "does not include button HTML" do
            get personalisation_check_email_subscription_path, params: params, headers: headers
            expect(response.body).not_to include("button_html")
          end

          context "when an active subscription has a matching slug" do
            let(:list_slug) { topic_slug }
            let(:active) { true }

            it "returns subscription status details as active" do
              get personalisation_check_email_subscription_path, params: params, headers: headers
              expect(JSON.parse(response.body)).to include(subscription_details)
            end

            it "does not include button HTML" do
              get personalisation_check_email_subscription_path, params: params, headers: headers
              expect(response.body).not_to include("button_html")
            end
          end
        end

        context "when the user does not have active subscriptions" do
          before { stub_email_alert_api_does_not_have_subscriber_subscriptions(subscriber_id) }

          it "returns subscription status details as not active" do
            get personalisation_check_email_subscription_path, params: params, headers: headers
            expect(JSON.parse(response.body)).to include(subscription_details)
          end

          it "does not include button HTML" do
            get personalisation_check_email_subscription_path, params: params, headers: headers
            expect(response.body).not_to include("button_html")
          end
        end
      end
    end
  end
end
