class ApplicationController < ActionController::API
  include GDS::SSO::ControllerMethods

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

  def to_account_session(access_token, refresh_token)
    "#{Base64.urlsafe_encode64(access_token)}.#{Base64.urlsafe_encode64(refresh_token)}"
  end

  def from_account_session(govuk_account_session)
    bits = (govuk_account_session || "").split(".")
    if bits.length == 2
      {
        access_token: Base64.urlsafe_decode64(bits[0]),
        refresh_token: Base64.urlsafe_decode64(bits[1]),
      }
    end
  end

protected

  def authorise
    authorise_user!("internal_app")
  end
end
