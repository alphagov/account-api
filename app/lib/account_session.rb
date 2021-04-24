# frozen_string_literal: true

class AccountSession
  LOWEST_LEVEL_OF_AUTHENTICATION = "level0"

  attr_accessor :access_token, :refresh_token, :level_of_authentication

  def initialize(session_signing_key:, access_token:, refresh_token:, level_of_authentication:)
    @session_signing_key = session_signing_key
    @access_token = access_token
    @refresh_token = refresh_token
    @level_of_authentication = level_of_authentication
  end

  def self.deserialise(encoded_session:, session_signing_key:)
    return if encoded_session.blank?

    serialised_session = StringEncryptor.new(signing_key: session_signing_key).decrypt_string(encoded_session)
    if serialised_session
      new(
        session_signing_key: session_signing_key,
        **{
          level_of_authentication: LOWEST_LEVEL_OF_AUTHENTICATION,
        }.merge(JSON.parse(serialised_session).symbolize_keys),
      )
    else
      deserialise_legacy_base64_session(
        encoded_session: encoded_session,
        session_signing_key: session_signing_key,
      )
    end
  end

  def self.deserialise_legacy_base64_session(encoded_session:, session_signing_key:)
    bits = (encoded_session || "").split(".")
    if bits.length == 2
      new(
        session_signing_key: session_signing_key,
        access_token: Base64.urlsafe_decode64(bits[0]),
        refresh_token: Base64.urlsafe_decode64(bits[1]),
        level_of_authentication: LOWEST_LEVEL_OF_AUTHENTICATION,
      )
    end
  rescue ArgumentError
    nil
  end

  def serialise
    StringEncryptor.new(signing_key: session_signing_key).encrypt_string(to_hash.to_json)
  end

  def to_hash
    {
      access_token: access_token,
      refresh_token: refresh_token,
      level_of_authentication: level_of_authentication,
    }
  end

private

  attr_reader :session_signing_key
end
