RSpec.describe "Saved pages" do
  context "when receiving an unauthenticated request" do
    it "returns unauthorised for GET /api/saved_pages" do
      get saved_pages_path

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns unauthorised for PUT /api/saved_pages/:page_path" do
      put saved_page_path({ page_path: "/my-saved-page-path" })

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns unauthorised for DELETE /api/saved_pages/:page_path" do
      delete saved_page_path({ page_path: "/my-saved-page-path" })

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns unauthorised for GET /api/saved_pages/:page_path " do
      get saved_page_path("/my-saved-page-path")

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

    describe "PUT /api/saved_pages/:page_path" do
      it "returns a page path hash if the page persists correctly" do
        put saved_page_path(page_path: "/page-path/1"), headers: headers

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)["saved_page"]).to eq({ "page_path" => "/page-path/1" })
      end

      it "returns status 200 and upserts the record if the page already exists" do
        FactoryBot.create(:saved_page, oidc_user_id: user.id, page_path: "/page-path/1")
        put saved_page_path(page_path: "/page-path/1"), headers: headers

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)["saved_page"]).to eq({ "page_path" => "/page-path/1" })
      end

      it "increases the count of saved pages if the page does not already exist" do
        expect {
          put saved_page_path(page_path: "/page-path/1"), headers: headers
        }.to change(SavedPage, :count).by(1)
      end

      it "does not increase the count of saved pages if the page does already exist" do
        FactoryBot.create(:saved_page, oidc_user_id: user.id, page_path: "/page-path/1")

        expect {
          put saved_page_path(page_path: "/page-path/1"), headers: headers
        }.not_to change(SavedPage, :count)
      end

      it "returns status 422 Unprocessable Entity with a RFC 7807 'problem detail' object if the page path contains query parameters" do
        page_path = "/foo/bar?uhoh"
        put saved_page_path(page_path: page_path), headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        error = JSON.parse(response.body)
        expect(error["title"]).to eq(I18n.t("errors.cannot_save_page.title"))
        expect(error["type"]).to eq(I18n.t("errors.cannot_save_page.type"))
        expect(error["detail"]).to eq(I18n.t("errors.cannot_save_page.detail", page_path: page_path))
        expect(error["page_path"]).to eq(page_path)
        expect(error["errors"]["page_path"]).to include("must only include URL path")
      end

      it "returns status 422 Unprocessable Entity with a RFC 7807 'problem detail' object if the page path contains a fragment identifier" do
        page_path = "/foo/bar#heading1"
        put saved_page_path(page_path: page_path), headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        error = JSON.parse(response.body)
        expect(error["title"]).to eq(I18n.t("errors.cannot_save_page.title"))
        expect(error["type"]).to eq(I18n.t("errors.cannot_save_page.type"))
        expect(error["detail"]).to eq(I18n.t("errors.cannot_save_page.detail", page_path: page_path))
        expect(error["page_path"]).to eq(page_path)
        expect(error["errors"]["page_path"]).to include("must only include URL path")
      end
    end

    describe "DELETE /api/saved_pages/:page_path" do
      it "returns status 204 No Content if a record has been sucessfully deleted" do
        FactoryBot.create(:saved_page, oidc_user_id: user.id, page_path: "/page-path/1")
        delete saved_page_path(page_path: "/page-path/1"), headers: headers

        expect(response).to have_http_status(:no_content)
      end

      it "decreases the count of saved pages" do
        FactoryBot.create(:saved_page, oidc_user_id: user.id, page_path: "/page-path/1")

        expect {
          delete saved_page_path(page_path: "/page-path/1"), headers: headers
        }.to change(SavedPage, :count).by(-1)
      end

      it "returns status 404 Not Found if there is no saved page with the provided path" do
        delete saved_page_path(page_path: "/page-path/1"), headers: headers

        expect(response).to have_http_status(:not_found)
      end
    end

    describe "GET /api/saved_pages/:page_path" do
      it "returns status 200 and a saved page record if a page exists" do
        FactoryBot.create(:saved_page, oidc_user_id: user.id, page_path: "/page-path/1")
        get saved_page_path(page_path: "/page-path/1"), headers: headers

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)["saved_page"]).to eq({ "page_path" => "/page-path/1" })
      end

      it "returns status 404 Not Found if there is no saved page with the provided path" do
        get saved_page_path(page_path: "/page-path/1"), headers: headers

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
