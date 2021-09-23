module GovukAccountSessionHelper
  def placeholder_govuk_account_session(options = {})
    placeholder_govuk_account_session_object(options).serialise
  end

  def placeholder_govuk_account_session_object(options = {})
    AccountSession.new(
      **{
        session_secret: Rails.application.secrets.session_secret,
        id_token: "id-token",
        user_id: "user-id",
        access_token: "access-token",
        refresh_token: "refresh-token",
        mfa: false,
      }.merge(options),
    )
  end
end

RSpec.configuration.send :include, GovukAccountSessionHelper
