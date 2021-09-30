RSpec.describe OidcUser do
  describe "validations" do
    it { is_expected.to validate_presence_of(:sub) }
  end

  describe "#find_or_create_by_sub!" do
    let(:sub) { "subject-identifier" }

    it "creates a new user" do
      expect { described_class.find_or_create_by_sub!(sub) }.to change(described_class, :count).by(1)
    end

    it "saves the sub and legacy_sub" do
      user = described_class.find_or_create_by_sub!(sub)
      expect(user.sub).to eq(sub)
      expect(user.legacy_sub).to eq(sub)
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
  end
end
