require "gds_api/test_helpers/email_alert_api"

RSpec.describe EmailSubscription do
  include GdsApi::TestHelpers::EmailAlertApi

  subject(:email_subscription) do
    FactoryBot.create(
      :email_subscription,
      oidc_user: oidc_user,
      name: name,
      email_alert_api_subscription_id: email_alert_api_subscription_id,
    )
  end

  let(:oidc_user) do
    FactoryBot.create(
      :oidc_user,
      has_received_transition_checker_onboarding_email: has_received_transition_checker_onboarding_email,
    )
  end

  let(:email) { "email@example.com" }
  let(:name) { "subscription-name" }
  let(:email_alert_api_subscription_id) { nil }
  let(:has_received_transition_checker_onboarding_email) { true }

  describe "associations" do
    it { is_expected.to belong_to(:oidc_user) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:topic_slug) }
  end

  describe "reactivate_if_confirmed!" do
    let(:email) { "email@example.com" }
    let(:email_verified) { false }

    before { email_subscription.oidc_user.set_local_attributes(email: email, email_verified: email_verified) }

    it "doesn't call email-alert-api if the user is not confirmed" do
      stub = stub_subscriber_list

      email_subscription.reactivate_if_confirmed!

      expect(stub).not_to have_been_made
    end

    context "when the user is confirmed" do
      let(:email_verified) { true }

      it "calls email-alert-api to create the subscription" do
        stub1 = stub_subscriber_list
        stub2 = stub_create_subscription

        email_subscription.reactivate_if_confirmed!

        expect(stub1).to have_been_made
        expect(stub2).to have_been_made
        expect(email_subscription.email_alert_api_subscription_id).to eq("new-subscription-id")
      end

      context "when this should trigger the Transition Checker onboarding email" do
        let(:name) { "transition-checker-results" }
        let(:has_received_transition_checker_onboarding_email) { false }

        it "sends the onboarding email" do
          stub_subscriber_list
          stub_create_subscription

          expect { email_subscription.reactivate_if_confirmed! }.to change(SendEmailWorker.jobs, :size).by(1)
        end
      end

      context "when the user has a prior subscription" do
        let(:email_alert_api_subscription_id) { "prior-subscription-id" }

        it "calls email-alert-api to remove the prior subscription" do
          stub = stub_email_alert_api_unsubscribes_a_subscription("prior-subscription-id")
          stub_subscriber_list
          stub_create_subscription

          email_subscription.reactivate_if_confirmed!

          expect(stub).to have_been_made
        end
      end

      def stub_create_subscription
        stub_email_alert_api_creates_a_subscription(
          subscriber_list_id: "list-id",
          address: email,
          frequency: "daily",
          returned_subscription_id: "new-subscription-id",
          skip_confirmation_email: true,
        )
      end
    end
  end

  describe "deactivate!" do
    subject(:email_subscription) { FactoryBot.build(:email_subscription, email_alert_api_subscription_id: "prior-subscription-id") }

    it "calls email-alert-api to remove the prior subscription and forgets the subscription id" do
      stub = stub_email_alert_api_unsubscribes_a_subscription("prior-subscription-id")

      email_subscription.deactivate!

      expect(email_subscription.reload.email_alert_api_subscription_id).to be_nil
      expect(stub).to have_been_made
    end

    context "when the subscription has been ended in email-alert-api" do
      before { stub_email_alert_api_has_no_subscription_for_uuid("prior-subscription-id") }

      it "sets the email_alert_api_subscription_id to nil" do
        email_subscription.deactivate!

        expect(email_subscription.reload.email_alert_api_subscription_id).to be_nil
      end
    end

    it "calls deactivate! on destroy" do
      stub = stub_email_alert_api_unsubscribes_a_subscription("prior-subscription-id")

      email_subscription.destroy!

      expect(stub).to have_been_made
    end
  end

  describe "#send_transition_checker_onboarding_email!" do
    it "does not send the email" do
      expect { email_subscription.send_transition_checker_onboarding_email! }.not_to change(SendEmailWorker.jobs, :size)
    end

    context "when the subscription has been activated" do
      let(:email_alert_api_subscription_id) { "subscription-id" }

      it "does not send the email" do
        expect { email_subscription.send_transition_checker_onboarding_email! }.not_to change(SendEmailWorker.jobs, :size)
      end

      context "when this is the transition checker subscription" do
        let(:name) { "transition-checker-results" }

        it "does not send the email" do
          expect { email_subscription.send_transition_checker_onboarding_email! }.not_to change(SendEmailWorker.jobs, :size)
        end

        context "when the user has not already received the onboarding email" do
          let(:has_received_transition_checker_onboarding_email) { false }

          it "sends the email and updates the user" do
            expect { email_subscription.send_transition_checker_onboarding_email! }.to change(SendEmailWorker.jobs, :size).by(1)
            expect(oidc_user.reload.has_received_transition_checker_onboarding_email).to be(true)
          end
        end
      end
    end
  end

  def stub_subscriber_list
    stub_email_alert_api_has_subscriber_list_by_slug(
      slug: email_subscription.topic_slug,
      returned_attributes: { id: "list-id" },
    )
  end
end
