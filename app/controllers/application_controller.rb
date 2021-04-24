class ApplicationController < ActionController::API
  include GDS::SSO::ControllerMethods

  before_action :authorise

  def fetch_govuk_account_session
    @govuk_account_session = AccountSession.deserialise(
      encoded_session: request.headers["HTTP_GOVUK_ACCOUNT_SESSION"],
      session_signing_key: Rails.application.secrets.session_signing_key,
    )

    head :unauthorized unless @govuk_account_session
  end

protected

  def authorise
    authorise_user!("internal_app")
  end
end
