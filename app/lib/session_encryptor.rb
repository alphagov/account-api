class SessionEncryptor
  KEY_LEN = ActiveSupport::MessageEncryptor.key_len

  def initialize(session_signing_key:)
    @session_signing_key = session_signing_key
  end

  def encrypt_session(access_token:, refresh_token:)
    encrypt_string(
      {
        access_token: access_token,
        refresh_token: refresh_token,
      }.to_json,
    )
  end

  def decrypt_session(ciphertext)
    return if ciphertext.blank?

    plaintext = decrypt_string(ciphertext)
    return unless plaintext

    JSON.parse(plaintext).symbolize_keys
  end

private

  attr_reader :session_signing_key

  def encrypt_string(plaintext)
    salt = SecureRandom.hex KEY_LEN
    ciphertext = encryptor(salt).encrypt_and_sign(plaintext)
    Base64.urlsafe_encode64("#{salt}$$#{ciphertext}")
  end

  def decrypt_string(ciphertext)
    bits = Base64.urlsafe_decode64(ciphertext).split("$$")
    return nil unless bits.length == 2

    salt = bits[0]
    message = bits[1]

    encryptor(salt).decrypt_and_verify(message)
  rescue ArgumentError
    nil
  rescue ActiveSupport::MessageEncryptor::InvalidMessage
    nil
  end

  def encryptor(salt)
    key = ActiveSupport::KeyGenerator.new(session_signing_key).generate_key(salt, KEY_LEN)
    ActiveSupport::MessageEncryptor.new key
  end
end
