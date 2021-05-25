RSpec.describe SavedPage do
  describe "validations" do
    let(:saved_page) { FactoryBot.build(:saved_page) }

    it "rejects duplicate saved pages, scoped to a user" do
      saved_page.save!
      duplicate = saved_page.dup
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:page_path]).to include("has already been taken")
    end

    it "allows duplicate saved pages, between different users" do
      saved_page.save!
      not_a_duplicate = FactoryBot.build(:saved_page, page_path: saved_page.page_path)
      expect(not_a_duplicate).to be_valid
    end

    it "rejects blank values as page paths" do
      [nil, ""].each do |blank_value|
        saved_page.page_path = blank_value
        expect(saved_page).not_to be_valid
        expect(saved_page.errors[:page_path]).to include("can't be blank")
      end
    end

    it "rejects paths that do not start with /" do
      saved_page.page_path = "foo"
      expect(saved_page).not_to be_valid
      expect(saved_page.errors[:page_path]).to include("must only include URL path")
    end

    it "rejects paths that contain spaces" do
      saved_page.page_path = "/foo bar"
      expect(saved_page).not_to be_valid
      expect(saved_page.errors[:page_path]).to include("must only include URL path")
    end

    it "rejects page paths with parameters" do
      saved_page.page_path = "/foo/bar?i_am_tracking_identifier=abc123"
      expect(saved_page).not_to be_valid
      expect(saved_page.errors[:page_path]).to include("must only include URL path")
    end

    it "rejects pages with fragment identifiers" do
      saved_page.page_path = "/guidance/about-the-thing#heading1"
      expect(saved_page).not_to be_valid
      expect(saved_page.errors[:page_path]).to include("must only include URL path")
    end
  end

  describe "to_hash" do
    let(:saved_page) { FactoryBot.build(:saved_page) }

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
