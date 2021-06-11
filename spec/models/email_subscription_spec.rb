RSpec.describe EmailSubscription do
  subject(:email_subscription) { FactoryBot.build(:email_subscription) }

  describe "associations" do
    it { is_expected.to belong_to(:oidc_user) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:topic_slug) }
  end
end
