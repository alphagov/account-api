RSpec.describe OidcUser do
  describe "validations" do
    it { is_expected.to validate_presence_of(:sub) }
  end

  describe "callbacks" do
    it "creates a tombstone record for the sub when destroyed" do
      sub = "subject-identifier"
      expect { described_class.create!(sub:).destroy! }.to change(Tombstone, :count).by(1)
      expect(Tombstone.find_by(sub:)).not_to be_nil
    end

    it "creates two tombstone records when two accounts with the same sub are deleted" do
      sub = "subject-identifier"
      Tombstone.destroy_all
      2.times do
        described_class.create!(sub:).destroy!
      end
      expect(Tombstone.count).to eq(2)
    end
  end

  describe "#find_or_create_by_sub!" do
    let(:sub) { "subject-identifier" }
    let(:legacy_sub) { "legacy-subject-identifier" }

    it "creates a new user" do
      expect { described_class.find_or_create_by_sub!(sub) }.to change(described_class, :count).by(1)
    end

    it "clears a LogoutNotice if one exists" do
      time = Time.zone.now
      Redis.new.set("logout-notice/#{sub}", time)
      expect {
        described_class.find_or_create_by_sub!(sub)
      }.to change {
        LogoutNotice.find(sub)
      }.from(time.strftime("%F %T %z")).to(nil)
    end

    it "saves the sub and legacy_sub" do
      user = described_class.find_or_create_by_sub!(sub, legacy_sub:)
      expect(user.sub).to eq(sub)
      expect(user.legacy_sub).to eq(legacy_sub)
    end

    context "when the user already exists" do
      let!(:user) { FactoryBot.create(:oidc_user, sub:) }

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
      let!(:user) { FactoryBot.create(:oidc_user, sub: "foo", legacy_sub:) }

      it "finds the user by legacy sub" do
        expect(described_class.find_or_create_by_sub!("bar", legacy_sub:).id).to eq(user.id)
      end

      it "updates the sub" do
        expect(described_class.find_or_create_by_sub!("bar", legacy_sub:).sub).to eq("bar")
      end
    end
  end
end
