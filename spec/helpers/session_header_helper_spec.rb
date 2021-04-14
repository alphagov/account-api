RSpec.describe SessionHeaderHelper do
  let(:tokens) { { access_token: SecureRandom.hex(10), refresh_token: SecureRandom.hex(10) } }

  it "round-trips" do
    encoded = to_account_session(*token_values(tokens))
    decoded = from_account_session(encoded)

    expect(decoded).to eq(tokens)
  end

  it "returns nil on a missing value" do
    expect(from_account_session(nil)).to be_nil
    expect(from_account_session("")).to be_nil
  end

  it "accepts a legacy unsigned session header" do
    encoded = "#{Base64.urlsafe_encode64(tokens[:access_token])}.#{Base64.urlsafe_encode64(tokens[:refresh_token])}"
    decoded = from_account_session(encoded)

    expect(decoded).to eq(tokens)
  end

  describe "from_legacy_account_session" do
    it "returns nil on invalid base64" do
      expect(from_legacy_account_session("?.?")).to be_nil
    end

    it "returns nil if there are the wrong number of fragments" do
      expect(from_legacy_account_session(Base64.urlsafe_encode64("1"))).to be_nil
      expect(from_legacy_account_session(Base64.urlsafe_encode64("1") + "." + Base64.urlsafe_encode64("2") + "." + Base64.urlsafe_encode64("3"))).to be_nil
    end
  end

  def token_values(access_token:, refresh_token:)
    [access_token, refresh_token]
  end
end
