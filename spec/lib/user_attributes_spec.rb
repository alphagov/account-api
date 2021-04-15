RSpec.describe UserAttributes do
  it "validates the config file" do
    expect(described_class.new.errors).to be_empty
  end
end
