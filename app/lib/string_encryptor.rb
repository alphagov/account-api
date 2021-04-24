class StringEncryptor
  KEY_LEN = ActiveSupport::MessageEncryptor.key_len

  def initialize(signing_key:)
    @signing_key = signing_key
  end

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

private

  attr_reader :signing_key

  def encryptor(salt)
    key = ActiveSupport::KeyGenerator.new(signing_key).generate_key(salt, KEY_LEN)
    ActiveSupport::MessageEncryptor.new key
  end
end
