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

  def account_session_header_value
    to_account_session(
      access_token: @govuk_account_session[:access_token],
      refresh_token: @govuk_account_session[:refresh_token],
      level_of_authentication: @govuk_account_session[:level_of_authentication],
    )
  end
end
