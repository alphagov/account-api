RSpec.describe AuthRequest do
  it "can be found from the OAuth state param" do
    request1 = described_class.create!(
      oauth_state: SecureRandom.alphanumeric(10),
      oidc_nonce: SecureRandom.alphanumeric(10),
      redirect_path: SecureRandom.alphanumeric(10),
    )
    request2 = described_class.create!(
      oauth_state: request1.oauth_state,
      oidc_nonce: request1.oidc_nonce,
      redirect_path: request1.redirect_path,
    )

    expect(described_class.from_oauth_state(request1.to_oauth_state).id).to eq(request1.id)
    expect(described_class.from_oauth_state(request2.to_oauth_state).id).to eq(request2.id)
  end
end
