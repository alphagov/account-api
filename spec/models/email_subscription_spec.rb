require "gds_api/test_helpers/email_alert_api"

RSpec.describe EmailSubscription do
  include GdsApi::TestHelpers::EmailAlertApi

  subject(:email_subscription) do
    FactoryBot.create(
      :email_subscription,
      oidc_user:,
      name:,
      email_alert_api_subscription_id:,
    )
  end

  let(:oidc_user) { FactoryBot.create(:oidc_user) }

  let(:email) { "email@example.com" }
  let(:name) { "subscription-name" }
  let(:email_alert_api_subscription_id) { nil }

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

    before { email_subscription.oidc_user.update!(email:, email_verified:) }

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

  def stub_subscriber_list
    stub_email_alert_api_has_subscriber_list_by_slug(
      slug: email_subscription.topic_slug,
      returned_attributes: { id: "list-id" },
    )
  end
end
