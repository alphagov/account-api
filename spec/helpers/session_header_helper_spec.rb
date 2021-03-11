RSpec.describe SessionHeaderHelper do
  let(:tokens) { { access_token: SecureRandom.bytes(10), refresh_token: SecureRandom.bytes(10) } }

  it "round-trips" do
    encoded = to_account_session(*token_values(tokens))
    decoded = from_account_session(encoded)

    expect(decoded).to eq(tokens)
  end

  def token_values(access_token:, refresh_token:)
    [access_token, refresh_token]
  end
end
