RSpec.describe UserAttributes do
  it "validates the config file" do
    expect(described_class.new.errors).to be_empty
  end

  describe "validation" do
    let(:attributes) { { "foo" => foo_properties, "bar" => bar_properties } }
    let(:foo_properties) { { "is_stored_locally" => true } }
    let(:bar_properties) { { "is_stored_locally" => false } }

    let(:errors) { described_class.validate(attributes) }

    it "accepts valid configuration" do
      expect(errors).to eq({})
    end

    context "when a key is missing" do
      let(:foo_properties) { {} }

      it "rejects" do
        expect(errors).to eq({ "foo" => { missing_keys: %w[is_stored_locally] } })
      end
    end

    context "when an unexpected key is present" do
      let(:bar_properties) { { "is_stored_loally" => true } }

      it "rejects" do
        expect(errors).to eq({ "bar" => { missing_keys: %w[is_stored_locally], unknown_keys: %w[is_stored_loally] } })
      end
    end

    context "when a key has an unexpected value" do
      let(:foo_properties) { { "is_stored_locally" => "truee" } }

      it "rejects" do
        expect(errors).to eq({ "foo" => { invalid_keys: %w[is_stored_locally] } })
      end
    end
  end
end
