class ApplicationController < ActionController::API
  include GDS::SSO::ControllerMethods
  include SessionHeaderHelper

  before_action :authorise

  def fetch_govuk_account_session
    govuk_account_session_header =
      if request.headers["HTTP_GOVUK_ACCOUNT_SESSION"]
        request.headers["HTTP_GOVUK_ACCOUNT_SESSION"]
      elsif request.headers.to_h["GOVUK-Account-Session"]
        request.headers.to_h["GOVUK-Account-Session"]
      end

    head :unauthorized and return unless govuk_account_session_header

    @govuk_account_session = from_account_session(govuk_account_session_header)
  end

protected

  def authorise
    authorise_user!("internal_app")
  end
end
