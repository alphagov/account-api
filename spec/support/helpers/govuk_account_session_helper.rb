module GovukAccountSessionHelper
  def placeholder_govuk_account_session(access_token: "access-token", refresh_token: "refresh-token")
    "#{Base64.urlsafe_encode64(access_token)}.#{Base64.urlsafe_encode64(refresh_token)}"
  end
end

RSpec.configuration.send :include, GovukAccountSessionHelper
