RSpec.describe AuthRequest do
  it "can be found from the OAuth state param" do
    request1 = FactoryBot.create(:auth_request, redirect_path: "/#{SecureRandom.alphanumeric(10)}")
    request2 = FactoryBot.create(:auth_request, redirect_path: request1.redirect_path)

    expect(described_class.from_oauth_state(request1.to_oauth_state).id).to eq(request1.id)
    expect(described_class.from_oauth_state(request2.to_oauth_state).id).to eq(request2.id)
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:oauth_state) }

    it { is_expected.to validate_presence_of(:oidc_nonce) }

    it "allows an empty redirect" do
      expect(described_class.new(oauth_state: "foo", oidc_nonce: "bar", redirect_path: "")).to be_valid
      expect(described_class.new(oauth_state: "foo", oidc_nonce: "bar", redirect_path: nil)).to be_valid
    end

    it "allows path-relative redirects" do
      expect(described_class.new(oauth_state: "foo", oidc_nonce: "bar", redirect_path: "/good-page")).to be_valid
    end

    it "allows querystrings" do
      expect(described_class.new(oauth_state: "foo", oidc_nonce: "bar", redirect_path: "/page/with/a?query=string")).to be_valid
    end

    it "forbids protocol-relative redirects" do
      expect(described_class.new(oauth_state: "foo", oidc_nonce: "bar", redirect_path: "//malicious-site.com")).not_to be_valid
    end

    it "forbids absolute redirects" do
      expect(described_class.new(oauth_state: "foo", oidc_nonce: "bar", redirect_path: "http://malicious-site.com")).not_to be_valid
      expect(described_class.new(oauth_state: "foo", oidc_nonce: "bar", redirect_path: "https://malicious-site.com")).not_to be_valid
    end
  end
end
