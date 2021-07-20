RSpec.describe AttributeDefinition do
  subject(:attribute) { described_class.new(type: :local) }

  it { is_expected.to validate_presence_of(:type) }
  it { is_expected.to validate_presence_of(:level_of_auth_check) }
  it { is_expected.to validate_presence_of(:level_of_auth_get) }
  it { is_expected.to validate_presence_of(:level_of_auth_set) }

  it { is_expected.to validate_inclusion_of(:type).in_array(%w[local remote cached]) }
  it { is_expected.to validate_exclusion_of(:writable).in_array([nil]) }

  it "validates that :level_of_auth_check <= :level_of_auth_get" do
    attribute = described_class.new(type: :local, level_of_auth_check: 9, level_of_auth_get: 0, level_of_auth_set: 0)
    attribute.valid?
    expect(attribute.errors[:level_of_auth_check]).not_to be_empty
  end

  it "validates that :level_of_auth_get <= :level_of_auth_set" do
    attribute = described_class.new(type: :local, level_of_auth_check: 0, level_of_auth_get: 9, level_of_auth_set: 0)
    attribute.valid?
    expect(attribute.errors[:level_of_auth_get]).not_to be_empty
  end

  context "when the attribute is not writable" do
    it "does not validate that :level_of_auth_get <= :level_of_auth_set" do
      attribute = described_class.new(type: :local, level_of_auth_check: 0, level_of_auth_get: 9, level_of_auth_set: 0, writable: false)
      attribute.valid?
      expect(attribute.errors[:level_of_auth_get]).to be_empty
    end
  end
end
