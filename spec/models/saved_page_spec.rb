RSpec.describe SavedPage do
  subject(:saved_page) { FactoryBot.build(:saved_page) }

  describe "associations" do
    it { is_expected.to belong_to(:oidc_user) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:page_path) }

    it { is_expected.to validate_uniqueness_of(:page_path).scoped_to(:oidc_user_id) }

    it "validates that page_path starts with /" do
      saved_page.page_path = "foo"
      expect(saved_page).not_to be_valid
      expect(saved_page.errors[:page_path]).to include("must only include URL path")
    end

    it "validates that page_path does not contain spaces" do
      saved_page.page_path = "/foo bar"
      expect(saved_page).not_to be_valid
      expect(saved_page.errors[:page_path]).to include("must only include URL path")
    end

    it "validates that page_path does not have parameters" do
      saved_page.page_path = "/foo/bar?i_am_tracking_identifier=abc123"
      expect(saved_page).not_to be_valid
      expect(saved_page.errors[:page_path]).to include("must only include URL path")
    end

    it "validates that page_path does not have fragment identifiers" do
      saved_page.page_path = "/guidance/about-the-thing#heading1"
      expect(saved_page).not_to be_valid
      expect(saved_page.errors[:page_path]).to include("must only include URL path")
    end
  end

  describe "#to_hash" do
    it "returns a hash with stringified keys containing the page path" do
      expect(saved_page.to_hash).to eq(
        {
          "page_path" => saved_page.page_path,
          "content_id" => saved_page.content_id,
          "title" => saved_page.title,
        },
      )
    end
  end

  describe ".updates_from_content_item" do
    context "when the content_item has a public_updated_at" do
      let(:public_updated_at) { "2020-08-31 07:24" }
      let(:content_item) { { "content_id" => :foo, "title" => :bar, "public_updated_at" => public_updated_at } }

      it "returns a hash with relevant content_item information with public_updated_at" do
        expect(described_class.updates_from_content_item(content_item)).to eq(
          { content_id: :foo, title: :bar, public_updated_at: Time.zone.parse(public_updated_at) },
        )
      end
    end

    context "when the content_item does not have a public_updated_at" do
      let(:content_item) { { "content_id" => :foo, "title" => :bar } }

      it "returns a hash with relevant content_item information without public_updated_at" do
        expect(described_class.updates_from_content_item(content_item)).to eq(
          { content_id: :foo, title: :bar, public_updated_at: nil },
        )
      end
    end
  end
end
