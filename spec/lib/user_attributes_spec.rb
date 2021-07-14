RSpec.describe UserAttributes do
  subject(:user_attributes) { described_class.new }

  describe "attribute definitions" do
    described_class.new.attributes.each do |name, attribute|
      it "#{name} is valid" do
        expect(attribute.valid?).to be(true)
      end
    end
  end

  describe "#level_of_authentication_for" do
    it "raises an error for an unknown permission level" do
      expect { user_attributes.level_of_authentication_for("attribute", :wizardry) }.to raise_error(UserAttributes::UnknownPermission)
    end
  end
end
