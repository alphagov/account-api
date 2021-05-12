RSpec.describe "Saved pages" do
  context "when receiving an unauthenticated request" do
    it "returns unauthorised for GET /api/saved_pages" do
      get saved_pages_path

      expect(response).to have_http_status(:unauthorized)
    end
  end

  context "when receiving an authenticated request" do
    let(:headers) { { "Content-Type" => "application/json", "GOVUK-Account-Session" => session_identifier } }
    let(:session_identifier) { placeholder_govuk_account_session(user_id: user.sub) }
    let(:user) { FactoryBot.create(:oidc_user) }

    describe "GET /api/saved_pages" do
      it "returns an empty array if there are no saved pages" do
        get saved_pages_path, headers: headers

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)["saved_pages"]).to eq([])
      end

      it "returns an array of saved_pages if they exist" do
        list = FactoryBot.create_list(:saved_page, 2, oidc_user_id: user.id)
        expected_response = list.map(&:to_hash)

        get saved_pages_path, headers: headers

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)["saved_pages"]).to eq(expected_response)
      end
    end
  end
end
