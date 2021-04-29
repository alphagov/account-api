RSpec.describe UserAttributes do
  it "validates the config file" do
    expect(described_class.new.errors).to be_empty
  end

  describe "validation" do
    let(:attributes) { { "foo" => foo_properties, "bar" => bar_properties } }
    let(:foo_properties) { { "is_stored_locally" => true, "permissions" => foo_permissions } }
    let(:foo_permissions) { { "check" => 0, "get" => 0, "set" => 1 } }
    let(:bar_properties) { { "is_stored_locally" => false, "permissions" => bar_permissions } }
    let(:bar_permissions) { { "check" => 1, "get" => 1, "set" => 1 } }

    let(:errors) { described_class.validate(attributes) }

    it "accepts valid configuration" do
      expect(errors).to eq({})
    end

    describe "errors with top-level keys" do
      context "when a key is missing" do
        let(:foo_properties) { {} }

        it "rejects" do
          expect(errors).to eq({ "foo" => { missing_keys: %w[is_stored_locally permissions] } })
        end
      end

      context "when an unexpected top-level key is present" do
        let(:bar_properties) { { "is_stored_loally" => true, "permissions" => bar_permissions } }

        it "rejects" do
          expect(errors).to eq({ "bar" => { missing_keys: %w[is_stored_locally], unknown_keys: %w[is_stored_loally] } })
        end
      end

      context "when a key has an unexpected value" do
        let(:foo_properties) { { "is_stored_locally" => "banana", "permissions" => foo_permissions } }

        it "rejects" do
          expect(errors).to eq({ "foo" => { invalid_keys: %w[is_stored_locally] } })
        end
      end
    end

    describe "errors with permission keys" do
      context "when a key is missing" do
        let(:foo_permissions) { { "get" => 1 } }

        it "rejects" do
          expect(errors).to eq({ "foo" => { missing_keys: %w[permissions.check permissions.set] } })
        end
      end

      context "when an unexpected key is present" do
        let(:foo_permissions) { { "check" => 1, "get" => 1, "sett" => 1 } }

        it "rejects" do
          expect(errors).to eq({ "foo" => { missing_keys: %w[permissions.set], unknown_keys: %w[permissions.sett] } })
        end
      end

      context "when a key has an non-integral value" do
        let(:foo_permissions) { { "check" => "apple", "get" => 1, "set" => 1 } }

        it "rejects" do
          expect(errors).to eq({ "foo" => { invalid_keys: %w[permissions.check] } })
        end
      end

      context "when check requires a higher permission than get" do
        let(:foo_permissions) { { "check" => 1, "get" => 0, "set" => 0 } }

        it "rejects" do
          expect(errors).to eq({ "foo" => { invalid_keys: %w[permissions.check] } })
        end
      end

      context "when get requires a higher permission than set" do
        let(:foo_permissions) { { "check" => 0, "get" => 1, "set" => 0 } }

        it "rejects" do
          expect(errors).to eq({ "foo" => { invalid_keys: %w[permissions.get] } })
        end
      end
    end
  end
end
