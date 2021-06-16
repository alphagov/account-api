RSpec.describe OidcUser do
  describe "associations" do
    it { is_expected.to have_many(:local_attributes) }

    it { is_expected.to have_many(:saved_pages) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:sub) }
  end
end
