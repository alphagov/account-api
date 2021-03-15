module SessionHeaderHelper
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
  rescue ArgumentError
    nil
  end
end
