RSpec.describe AttributeDefinition do
  subject(:attribute) { described_class.new }

  it { is_expected.to validate_exclusion_of(:check_requires_mfa).in_array([nil]) }
  it { is_expected.to validate_exclusion_of(:get_requires_mfa).in_array([nil]) }
  it { is_expected.to validate_exclusion_of(:set_requires_mfa).in_array([nil]) }
  it { is_expected.to validate_exclusion_of(:writable).in_array([nil]) }

  it "validates that :check_requires_mfa implies :get_requires_mfa" do
    attribute = described_class.new(check_requires_mfa: true, get_requires_mfa: false, set_requires_mfa: false)
    attribute.valid?
    expect(attribute.errors[:check_requires_mfa]).not_to be_empty
  end

  it "validates that :get_requires_mfa implies :set_requires_mfa" do
    attribute = described_class.new(check_requires_mfa: false, get_requires_mfa: true, set_requires_mfa: false)
    attribute.valid?
    expect(attribute.errors[:get_requires_mfa]).not_to be_empty
  end

  context "when the attribute is not writable" do
    it "does not validate that :get_requires_mfa implies :set_requires_mfa" do
      attribute = described_class.new(check_requires_mfa: false, get_requires_mfa: true, set_requires_mfa: false, writable: false)
      attribute.valid?
      expect(attribute.errors[:get_requires_mfa]).to be_empty
    end
  end
end
