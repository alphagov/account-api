class SavedPagesController < ApplicationController
  include AuthenticatedApiConcern

  before_action :check_saved_page_exists, only: %i[destroy show]

  # GET /api/saved_pages
  def index
    render_api_response(saved_pages: user.saved_pages.map(&:to_hash))
  end

  # GET /api/saved_pages/:page_path
  def show
    render_api_response(saved_page: saved_page.to_hash)
  end

  # PUT /api/saved_pages/:page_path
  def update
    SavedPage.transaction do
      saved_page = SavedPage
        .create_with(content_id: "00000000-0000-0000-0000-000000000000")
        .find_or_create_by(oidc_user_id: user.id, page_path: params[:page_path])

      if saved_page.persisted?
        content_item = GdsApi.content_store.content_item(params[:page_path]).to_hash

        if %w[gone redirect].include? content_item["document_type"]
          raise GdsApi::HTTPGone, 410
        else
          saved_page.update!(**SavedPage.updates_from_content_item(content_item))

          render_api_response(saved_page: saved_page.to_hash)
        end
      else
        raise ApiError::CannotSavePage, { page_path: params[:page_path], errors: saved_page.errors }
      end
    end
  rescue GdsApi::HTTPNotFound
    head :not_found
  rescue GdsApi::HTTPGone
    head :gone
  end

  # DELETE /api/saved_pages/:page_path
  def destroy
    saved_page.destroy!
    head :no_content
  end

private

  def user
    @user ||= @govuk_account_session.user
  end

  def saved_page
    @saved_page ||= SavedPage.find_by(oidc_user_id: user.id, page_path: params[:page_path])
  end

  def check_saved_page_exists
    head :not_found if saved_page.nil?
  end
end
