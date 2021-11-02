RSpec.describe Tombstone do
  describe "validations" do
    it { is_expected.to validate_presence_of(:sub) }
  end
end
