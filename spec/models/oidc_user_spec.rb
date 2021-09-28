RSpec.describe OidcUser do
  describe "validations" do
    it { is_expected.to validate_presence_of(:sub) }
  end

  describe "#find_or_create_by_sub!" do
    let(:sub) { "subject-identifier" }

    it "creates a new user" do
      expect { described_class.find_or_create_by_sub!(sub) }.to change(described_class, :count).by(1)
      expect(described_class.find_or_create_by_sub!(sub).sub).to eq(sub)
    end

    context "when the user already exists" do
      before { described_class.create!(sub: sub) }

      it "returns the existing model" do
        old_user = described_class.find_by!(sub: sub)
        expect { described_class.find_or_create_by_sub!(sub) }.not_to change(described_class, :count)
        expect(described_class.find_or_create_by_sub!(sub).id).to eq(old_user.id)
      end
    end
  end
end
