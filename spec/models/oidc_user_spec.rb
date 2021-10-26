RSpec.describe OidcUser do
  describe "validations" do
    it { is_expected.to validate_presence_of(:sub) }
  end

  describe "callbacks" do
    it "creates a tombstone record for the sub when destroyed" do
      sub = "subject-identifier"
      expect { described_class.create!(sub: sub).destroy! }.to change(Tombstone, :count).by(1)
      expect(Tombstone.find_by(sub: sub)).not_to be_nil
    end

    it "creates a tombstone record for the legacy_sub when destroyed" do
      sub = "subject-identifier"
      legacy_sub = "legacy-subject-identifier"
      expect { described_class.create!(sub: sub, legacy_sub: legacy_sub).destroy! }.to change(Tombstone, :count).by(2)
      expect(Tombstone.find_by(sub: sub)).not_to be_nil
      expect(Tombstone.find_by(sub: legacy_sub)).not_to be_nil
    end
  end

  describe "#find_or_create_by_sub!" do
    let(:sub) { "subject-identifier" }
    let(:legacy_sub) { "legacy-subject-identifier" }

    it "creates a new user" do
      expect { described_class.find_or_create_by_sub!(sub) }.to change(described_class, :count).by(1)
    end

    it "saves the sub and legacy_sub" do
      user = described_class.find_or_create_by_sub!(sub, legacy_sub: legacy_sub)
      expect(user.sub).to eq(sub)
      expect(user.legacy_sub).to eq(legacy_sub)
    end

    context "when the user already exists" do
      let!(:user) { FactoryBot.create(:oidc_user, sub: sub) }

      it "returns the existing model" do
        expect { described_class.find_or_create_by_sub!(sub) }.not_to change(described_class, :count)
        expect(described_class.find_or_create_by_sub!(sub).id).to eq(user.id)
      end

      it "doesn't change the legacy_sub" do
        user.update!(legacy_sub: "some-other-value")
        expect { described_class.find_or_create_by_sub!(sub) }.not_to change(user, :legacy_sub)
      end
    end

    context "when the sub does not match but the legacy sub does" do
      let!(:user) { FactoryBot.create(:oidc_user, sub: "foo", legacy_sub: legacy_sub) }

      it "finds the user by legacy sub" do
        expect(described_class.find_or_create_by_sub!("bar", legacy_sub: legacy_sub).id).to eq(user.id)
      end

      it "updates the sub" do
        expect(described_class.find_or_create_by_sub!("bar", legacy_sub: legacy_sub).sub).to eq("bar")
      end
    end
  end
end
