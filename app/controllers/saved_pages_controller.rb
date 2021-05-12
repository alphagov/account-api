class SavedPagesController < ApplicationController
  include AuthenticatedApiConcern

  # GET /api/saved_pages
  def index
    render_api_response(saved_pages: user.saved_pages.map(&:to_hash))
  end

private

  def user
    @user ||= @govuk_account_session.user
  end
end
