class ApplicationController < ActionController::API
  include GDS::SSO::ControllerMethods

  before_action :authorise!

  rescue_from ApiError::Base, with: :json_api_error

  def require_govuk_account_session!
    @govuk_account_session = AccountSession.deserialise(
      encoded_session: request.headers["HTTP_GOVUK_ACCOUNT_SESSION"],
      session_signing_key: Rails.application.secrets.session_signing_key,
    )

    head :unauthorized unless @govuk_account_session
  end

private

  def authorise!
    authorise_user!("internal_app")
  end

  def json_api_error(error)
    render status: error.status_code, json: {
      type: error.type,
      title: error.title,
      detail: error.detail,
    }.merge(error.extra_detail)
  end
end
