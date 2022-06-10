require "gds_api/test_helpers/email_alert_api"

RSpec.describe "Email subscriptions" do
  include GdsApi::TestHelpers::EmailAlertApi

  let(:headers) { { "Content-Type" => "application/json", "GOVUK-Account-Session" => session_identifier.serialise } }
  let(:session_identifier) { placeholder_govuk_account_session_object }

  describe "GET /api/email-subscriptions/:subscription_name" do
    it "returns a 404" do
      get email_subscription_path(subscription_name: "foo"), headers: headers
      expect(response).to have_http_status(:not_found)
    end

    context "when the subscription exists" do
      before do
        stub_email_alert_api_has_subscription(
          email_subscription.email_alert_api_subscription_id,
          "daily",
          ended: subscription_ended,
        )
      end

      let(:email_subscription) do
        FactoryBot.create(:email_subscription, oidc_user: session_identifier.user, email_alert_api_subscription_id: "prior-subscription-id")
      end

      let(:subscription_ended) { false }

      it "returns the subscription details" do
        get email_subscription_path(subscription_name: email_subscription.name), headers: headers
        expect(response).to be_successful
        expect(JSON.parse(response.body)["email_subscription"]).to eq(email_subscription.to_hash)
      end

      context "when the subscription has been ended in email-alert-api" do
        let(:subscription_ended) { true }

        it "deletes the subscription here and returns a 404" do
          stub_email_alert_api_unsubscribes_a_subscription(email_subscription.email_alert_api_subscription_id)
          expect { get email_subscription_path(subscription_name: email_subscription.name), headers: headers }.to change(EmailSubscription, :count).by(-1)
          expect(response).to have_http_status(:not_found)
        end
      end
    end
  end

  describe "PUT /api/email-subscriptions/:subscription_name" do
    let(:params) { { topic_slug: "slug" } }
    let(:email) { "email@example.com" }
    let(:email_verified) { false }

    it "creates a new subscription record if one doesn't already exist" do
      stub_local_attributes

      expect { put email_subscription_path(subscription_name: "name"), params: params.to_json, headers: headers }.to change(EmailSubscription, :count).by(1)

      expect(response).to be_successful
      expect(JSON.parse(response.body)["email_subscription"]).to eq(EmailSubscription.last.to_hash)
    end

    context "when the email and email verified attributes are not cached locally" do
      it "returns a 401" do
        expect { put email_subscription_path(subscription_name: "name"), params: params.to_json, headers: headers }.not_to change(EmailSubscription, :count)

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when the user has verified their email address" do
      let(:email_verified) { true }

      it "calls email-alert-api to create the subscription" do
        expect_activate_email_subscription do
          stub_local_attributes

          expect { put email_subscription_path(subscription_name: "name"), params: params.to_json, headers: headers }.to change(EmailSubscription, :count).by(1)

          expect(response).to be_successful
          expect(JSON.parse(response.body)["email_subscription"]).to eq(EmailSubscription.last.to_hash)
        end
      end
    end

    context "when the subscription already exists" do
      let!(:email_subscription) do
        FactoryBot.create(:email_subscription, oidc_user: session_identifier.user, email_alert_api_subscription_id: "prior-subscription-id")
      end

      before { stub_local_attributes }

      it "calls email-alert-api to deactivate the old subscription" do
        stub_cancel_old = stub_email_alert_api_unsubscribes_a_subscription(email_subscription.email_alert_api_subscription_id)

        put email_subscription_path(subscription_name: email_subscription.name), params: params.to_json, headers: headers

        expect(response).to be_successful
        expect(JSON.parse(response.body)["email_subscription"]).to eq(EmailSubscription.last.to_hash)
        expect(stub_cancel_old).to have_been_made
      end

      context "when the user has verified their email address" do
        let(:email_verified) { true }

        it "calls email-alert-api to create the new subscription" do
          expect_activate_email_subscription do
            stub_email_alert_api_unsubscribes_a_subscription(email_subscription.email_alert_api_subscription_id)

            put email_subscription_path(subscription_name: email_subscription.name), params: params.to_json, headers: headers

            expect(response).to be_successful
            expect(JSON.parse(response.body)["email_subscription"]).to eq(EmailSubscription.last.to_hash)
          end
        end
      end
    end

    def stub_local_attributes
      session_identifier.user.update!(
        email: email,
        email_verified: email_verified,
      )
    end

    def expect_activate_email_subscription
      stub_fetch_topic = stub_email_alert_api_has_subscriber_list_by_slug(
        slug: params[:topic_slug],
        returned_attributes: { id: "list-id" },
      )

      stub_create_new = stub_email_alert_api_creates_a_subscription(
        subscriber_list_id: "list-id",
        address: "email@example.com",
        frequency: "daily",
        returned_subscription_id: "new-subscription-id",
        skip_confirmation_email: true,
      )

      yield

      expect(stub_fetch_topic).to have_been_made
      expect(stub_create_new).to have_been_made
    end
  end

  describe "DELETE /api/email-subscriptions/:subscription_name" do
    it "returns a 404" do
      delete email_subscription_path(subscription_name: "foo"), headers: headers
      expect(response).to have_http_status(:not_found)
    end

    context "when the subscription exists" do
      let!(:email_subscription) do
        FactoryBot.create(:email_subscription, oidc_user: session_identifier.user, email_alert_api_subscription_id: "prior-subscription-id")
      end

      it "deletes it, calls email-alert-api to cancel the old subscription, and returns a 204" do
        stub_cancel_old = stub_email_alert_api_unsubscribes_a_subscription(email_subscription.email_alert_api_subscription_id)

        expect { delete email_subscription_path(subscription_name: email_subscription.name), headers: headers }.to change(EmailSubscription, :count).by(-1)

        expect(response).to have_http_status(:no_content)
        expect(stub_cancel_old).to have_been_made
      end
    end
  end
end
