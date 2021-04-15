RSpec.describe SessionEncryptor do
  let(:key) { "encryption-key" }
  let(:encoded) do
    described_class
      .new(session_signing_key: key)
      .encrypt_session(
        access_token: "access-token",
        refresh_token: "refresh-token",
        level_of_authentication: "level42",
      )
  end

  it "rejects if the salt has been tampered with" do
    bits = Base64.urlsafe_decode64(encoded).split("$$")
    salt = bits[0]
    message = bits[1]
    salt[0] = "X"
    new_encoded = Base64.urlsafe_encode64("#{salt}$$#{message}")

    expect(described_class.new(session_signing_key: key).decrypt_session(new_encoded)).to be_nil
  end

  it "rejects if the salt is missing" do
    message = Base64.urlsafe_decode64(encoded).split("$$")[1]
    new_encoded = Base64.urlsafe_encode64(message)

    expect(described_class.new(session_signing_key: key).decrypt_session(new_encoded)).to be_nil
  end

  it "rejects if the session has been signed with a different key" do
    expect(described_class.new(session_signing_key: "a-different-key").decrypt_session(encoded)).to be_nil
  end

  it "rejects if the session is invalid base64" do
    expect(described_class.new(session_signing_key: key).decrypt_session("?")).to be_nil
    expect(described_class.new(session_signing_key: key).decrypt_session("")).to be_nil
    expect(described_class.new(session_signing_key: key).decrypt_session(nil)).to be_nil
  end
end
