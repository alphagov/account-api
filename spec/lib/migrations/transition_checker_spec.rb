RSpec.describe Migrations::TransitionChecker do
  let(:subject_identifier) { SecureRandom.uuid }
  let(:transition_checker_state) { { foo: "bar" } }
  let(:topic_slug) { "topic-slug" }
  let(:subscription_id) { "subscription-id" }

  before do
    user = {
      subject_identifier: subject_identifier,
      transition_checker_state: transition_checker_state,
      topic_slug: topic_slug,
      email_alert_api_subscription_id: subscription_id,
    }

    stub_page(0, users: [user], is_last_page: true)
  end

  it "pages through the results" do
    stub_page0 = stub_page(0)
    stub_page1 = stub_page(1)
    stub_page2 = stub_page(2, is_last_page: true)

    described_class.call("dummy-token")

    expect(stub_page0).to have_been_made
    expect(stub_page1).to have_been_made
    expect(stub_page2).to have_been_made
  end

  shared_examples "imports the attribute" do
    it "imports the attribute" do
      expect { described_class.call("dummy-token") }.to change(LocalAttribute, :count).by(1)
      expect(LocalAttribute.where(oidc_user_id: oidc_user.id, name: "transition_checker_state", value: transition_checker_state).exists?).to be(true)
    end
  end

  shared_examples "imports the email subscription" do
    it "imports the email subscription" do
      expect { described_class.call("dummy-token") }.to change(EmailSubscription, :count).by(1)
      expect(EmailSubscription.where(oidc_user_id: oidc_user.id, name: "transition-checker-results", topic_slug: topic_slug, email_alert_api_subscription_id: subscription_id).exists?).to be(true)
    end
  end

  context "when the user is new" do
    let(:oidc_user) { OidcUser.find_by(sub: subject_identifier) }

    it "creates the user" do
      expect { described_class.call("dummy-token") }.to change(OidcUser, :count).by(1)
      expect(oidc_user).not_to be_nil
    end

    include_examples "imports the attribute"
    include_examples "imports the email subscription"
  end

  context "when the user already exists in the database" do
    let!(:oidc_user) { FactoryBot.create(:oidc_user, sub: subject_identifier) }

    it "does not create the user" do
      expect { described_class.call("dummy-token") }.not_to change(OidcUser, :count)
    end

    include_examples "imports the attribute"
    include_examples "imports the email subscription"

    context "when the user already has the attribute" do
      let!(:local_attribute) { FactoryBot.create(:local_attribute, oidc_user: oidc_user, name: "transition_checker_state", value: "old-value") }

      it "does not import the attribute" do
        old_value = local_attribute.value
        expect { described_class.call("dummy-token") }.not_to change(LocalAttribute, :count)
        expect(local_attribute.reload.value).to eq(old_value)
      end

      include_examples "imports the email subscription"
    end

    context "when the user already has the email subscription" do
      let!(:email_subscription) { FactoryBot.create(:email_subscription, oidc_user: oidc_user, name: "transition-checker-results", topic_slug: "old-slug") }

      it "does not import the email subscription" do
        old_topic_slug = email_subscription.topic_slug
        old_subscription_id = email_subscription.email_alert_api_subscription_id
        expect { described_class.call("dummy-token") }.not_to change(EmailSubscription, :count)
        expect(email_subscription.reload.topic_slug).to eq(old_topic_slug)
        expect(email_subscription.reload.email_alert_api_subscription_id).to eq(old_subscription_id)
      end

      include_examples "imports the attribute"
    end
  end

  def stub_page(page, users: [], is_last_page: false)
    stub_request(:get, "http://account-manager.dev.gov.uk/api/v1/migrate-users-to-account-api?page=#{page}")
      .to_return(body: { users: users, is_last_page: is_last_page }.to_json, headers: { content_type: "application/json" })
  end
end
