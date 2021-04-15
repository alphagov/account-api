module SessionHeaderHelper
  def to_account_session(access_token:, refresh_token:)
    SessionEncryptor
      .new(session_signing_key: Rails.application.secrets.session_signing_key)
      .encrypt_session(
        access_token: access_token,
        refresh_token: refresh_token,
      )
  end

  def from_account_session(govuk_account_session)
    return if govuk_account_session.blank?

    from_signed_account_session(govuk_account_session) || from_legacy_account_session(govuk_account_session)
  end

  def from_signed_account_session(govuk_account_session)
    SessionEncryptor
      .new(session_signing_key: Rails.application.secrets.session_signing_key)
      .decrypt_session(govuk_account_session)
  end

  def from_legacy_account_session(govuk_account_session)
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
