RSpec.describe StringEncryptor do
  let(:key) { "encryption-key" }
  let(:plaintext) { SecureRandom.hex(32) }
  let(:ciphertext) { described_class.new(secret: key).encrypt_string(plaintext) }

  it "round-trips" do
    expect(described_class.new(secret: key).decrypt_string(ciphertext)).to eq(plaintext)
  end

  it "rejects if the salt has been tampered with" do
    bits = Base64.urlsafe_decode64(ciphertext).split("$$")
    salt = bits[0]
    message = bits[1]
    salt[0] = "X"
    new_ciphertext = Base64.urlsafe_encode64("#{salt}$$#{message}")

    expect(described_class.new(secret: key).decrypt_string(new_ciphertext)).to be_nil
  end

  it "rejects if the salt is missing" do
    message = Base64.urlsafe_decode64(ciphertext).split("$$")[1]
    new_ciphertext = Base64.urlsafe_encode64(message)

    expect(described_class.new(secret: key).decrypt_string(new_ciphertext)).to be_nil
  end

  it "rejects if the string has been signed with a different key" do
    expect(described_class.new(secret: "a-different-key").decrypt_string(ciphertext)).to be_nil
  end
end
