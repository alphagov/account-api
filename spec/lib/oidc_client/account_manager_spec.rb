RSpec.describe OidcClient::AccountManager do
  subject(:client) { described_class.new }

  before { stub_oidc_discovery }

  describe "auth_uri" do
    it "includes the requested level of authentication in the scopes" do
      expect(client.auth_uri(AuthRequest.generate!, "level1234567890")).to include("scope=email%20openid%20level1234567890")
    end
  end

  describe "get_ephemeral_state" do
    it "returns {} if there is no JSON" do
      stub_request(:get, "#{Plek.find('account-manager')}/api/v1/ephemeral-state").to_return(body: "")

      expect(client.get_ephemeral_state(access_token: "access-token", refresh_token: "refresh-token")).to eq({ access_token: "access-token", refresh_token: "refresh-token", result: {} })
    end
  end
end
