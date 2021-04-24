RSpec.describe AccountSession do
  let(:access_token) { SecureRandom.hex(10) }
  let(:refresh_token) { SecureRandom.hex(10) }
  let(:level_of_authentication) { AccountSession::LOWEST_LEVEL_OF_AUTHENTICATION }
  let(:params) { { access_token: access_token, refresh_token: refresh_token, level_of_authentication: level_of_authentication } }

  it "round-trips" do
    encoded = described_class.new(session_signing_key: "secret", **params).serialise
    decoded = described_class.deserialise(encoded_session: encoded, session_signing_key: "secret").to_hash

    expect(decoded).to eq(params)
  end

  it "rejects a session signed with a different key" do
    encoded = described_class.new(session_signing_key: "secret", **params).serialise
    decoded = described_class.deserialise(encoded_session: encoded, session_signing_key: "different-secret")

    expect(decoded).to be_nil
  end

  it "returns nil on a missing value" do
    expect(described_class.deserialise(encoded_session: nil, session_signing_key: "secret")).to be_nil
    expect(described_class.deserialise(encoded_session: "", session_signing_key: "secret")).to be_nil
  end

  it "accepts a legacy unsigned session header" do
    encoded = "#{Base64.urlsafe_encode64(access_token)}.#{Base64.urlsafe_encode64(refresh_token)}"
    decoded = described_class.deserialise(encoded_session: encoded, session_signing_key: "secret").to_hash

    expect(decoded).to eq(params)
  end

  describe "deserialise_legacy_base64_session" do
    it "returns nil on invalid base64" do
      expect(described_class.deserialise_legacy_base64_session(encoded_session: "?.?", session_signing_key: "secret")).to be_nil
    end

    it "returns nil if there are the wrong number of fragments" do
      expect(described_class.deserialise_legacy_base64_session(encoded_session: Base64.urlsafe_encode64("1"), session_signing_key: "secret")).to be_nil
      expect(described_class.deserialise_legacy_base64_session(encoded_session: Base64.urlsafe_encode64("1") + "." + Base64.urlsafe_encode64("2") + "." + Base64.urlsafe_encode64("3"), session_signing_key: "secret")).to be_nil
    end
  end
end
