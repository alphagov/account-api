RSpec.describe AuthRequest do
  it "can be found from the OAuth state param" do
    request1 = described_class.create!(
      oauth_state: SecureRandom.alphanumeric(10),
      oidc_nonce: SecureRandom.alphanumeric(10),
      redirect_path: "/" + SecureRandom.alphanumeric(10),
    )
    request2 = described_class.create!(
      oauth_state: request1.oauth_state,
      oidc_nonce: request1.oidc_nonce,
      redirect_path: request1.redirect_path,
    )

    expect(described_class.from_oauth_state(request1.to_oauth_state).id).to eq(request1.id)
    expect(described_class.from_oauth_state(request2.to_oauth_state).id).to eq(request2.id)
  end

  it "allows an empty redirect" do
    expect(described_class.new(oauth_state: "foo", oidc_nonce: "bar", redirect_path: "")).to be_valid
    expect(described_class.new(oauth_state: "foo", oidc_nonce: "bar", redirect_path: nil)).to be_valid
  end

  it "allows path-relative redirects" do
    expect(described_class.new(oauth_state: "foo", oidc_nonce: "bar", redirect_path: "/good-page")).to be_valid
  end

  it "forbids protocol-relative redirects" do
    expect(described_class.new(oauth_state: "foo", oidc_nonce: "bar", redirect_path: "//malicious-site.com")).not_to be_valid
  end

  it "forbids absolute redirects" do
    expect(described_class.new(oauth_state: "foo", oidc_nonce: "bar", redirect_path: "http://malicious-site.com")).not_to be_valid
    expect(described_class.new(oauth_state: "foo", oidc_nonce: "bar", redirect_path: "https://malicious-site.com")).not_to be_valid
  end
end
