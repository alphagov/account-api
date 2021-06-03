RSpec.describe LocalAttribute do
  subject(:local_attribute) { FactoryBot.build(:local_attribute) }

  describe "associations" do
    it { is_expected.to belong_to(:oidc_user) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }

    it { is_expected.to validate_uniqueness_of(:name).scoped_to(:oidc_user_id) }

    it { is_expected.to validate_presence_of(:value) }
  end
end
