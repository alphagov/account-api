class ApplicationController < ActionController::API
  include GDS::SSO::ControllerMethods
  include SessionHeaderHelper

  before_action :authorise

  def fetch_govuk_account_session
    govuk_account_session_header = request.headers["HTTP_GOVUK_ACCOUNT_SESSION"]

    @govuk_account_session = from_account_session(govuk_account_session_header)

    head :unauthorized unless @govuk_account_session
  end

protected

  def authorise
    authorise_user!("internal_app")
  end
end
