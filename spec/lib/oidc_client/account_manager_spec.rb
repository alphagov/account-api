RSpec.describe OidcClient::AccountManager do
  subject(:client) { described_class.new }

  before { stub_oidc_discovery }

  describe "auth_uri" do
    it "includes level0 in the scopes when MFA is not required" do
      expect(client.auth_uri(AuthRequest.generate!, mfa: false)).to include("scope=email%20openid%20level0")
    end

    it "includes level1 in the scopes when MFA is required" do
      expect(client.auth_uri(AuthRequest.generate!, mfa: true)).to include("scope=email%20openid%20level1")
    end
  end

  describe "get_ephemeral_state" do
    it "returns {} if there is no JSON" do
      stub_request(:get, "#{Plek.find('account-manager')}/api/v1/ephemeral-state").to_return(body: "")

      expect(client.get_ephemeral_state(access_token: "access-token", refresh_token: "refresh-token")).to eq({ access_token: "access-token", refresh_token: "refresh-token", result: {} })
    end
  end
end
