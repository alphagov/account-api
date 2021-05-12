RSpec.describe SavedPage do
  describe "to_hash" do
    let(:saved_page) { FactoryBot.build(:saved_page) }

    it "returns a hash with stringified keys containing the page path" do
      expect(saved_page.to_hash).to eq({ "page_path" => saved_page.page_path })
    end
  end
end
