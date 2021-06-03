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
end
