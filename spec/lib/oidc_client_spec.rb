RSpec.describe OidcClient do
  subject(:client) { described_class.new }

  before { stub_oidc_discovery }

  describe "tokens!" do
    before do
      access_token = Rack::OAuth2::AccessToken.new(
        access_token: "access-token",
        refresh_token: "refresh-token",
        token_type: "test",
      )

      @client_stub = stub_oidc_client(client)
      # rubocop:disable RSpec/InstanceVariable
      allow(@client_stub).to receive(:access_token!).and_return(access_token)
      # rubocop:enable RSpec/InstanceVariable
    end

    it "doesn't fetch an ID token by default" do
      expect(client.tokens!).to eq({ access_token: "access-token", refresh_token: "refresh-token" })
    end

    it "fetches an ID token if a nonce is provided" do
      # the OAuth2::AccessToken type doesn't implement #id_token, so we get a NoMethodError
      expect { client.tokens!(oidc_nonce: "nonce") }.to raise_error(NoMethodError)
    end

    it "converts a Rack::OAuth2 error into an OAuthFailure" do
      # rubocop:disable RSpec/InstanceVariable
      allow(@client_stub).to receive(:access_token!).and_raise(Rack::OAuth2::Client::Error.new(401, { error: "error", error_description: "description" }))
      # rubocop:enable RSpec/InstanceVariable

      expect { client.tokens! }.to raise_error(OidcClient::OAuthFailure)
    end

    it "uses JWT auth" do
      # rubocop:disable RSpec/InstanceVariable
      expect(@client_stub).to receive(:access_token!).with(hash_including(client_auth_method: "jwt_bearer"))
      # rubocop:enable RSpec/InstanceVariable
      client.tokens!
    end

    context "when there is no OAuth private key" do
      # rubocop:disable RSpec/SubjectStub
      before { allow(client).to receive(:use_client_private_key_auth?).and_return(false) }
      # rubocop:enable RSpec/SubjectStub

      it "does not use JWT auth" do
        # rubocop:disable RSpec/InstanceVariable
        expect(@client_stub).to receive(:access_token!).with(no_args)
        # rubocop:enable RSpec/InstanceVariable
        client.tokens!
      end
    end
  end

  describe "the access token has expired" do
    before do
      client_stub = stub_oidc_client(client)

      new_access_token = Rack::OAuth2::AccessToken::Bearer.new(
        access_token: "new-access-token",
        refresh_token: "new-refresh-token",
      )

      allow(client_stub).to receive(:"refresh_token=").with("refresh-token")
      allow(client_stub).to receive(:access_token!).and_return(new_access_token)

      @stub_fail = stub_request(:get, "http://openid-provider/userinfo-endpoint")
        .with(headers: { Authorization: "Bearer access-token" })
        .to_return(status: 401)
    end

    it "refreshes the token and retries" do
      stub_success = stub_request(:get, "http://openid-provider/userinfo-endpoint")
        .with(headers: { Authorization: "Bearer new-access-token" })
        .to_return(status: 200, body: { id: "foo" }.to_json)

      client.userinfo(access_token: "access-token", refresh_token: "refresh-token")

      # rubocop:disable RSpec/InstanceVariable
      expect(@stub_fail).to have_been_made
      # rubocop:enable RSpec/InstanceVariable
      expect(stub_success).to have_been_made
    end

    context "but there is no refresh token" do
      it "fails" do
        expect { client.userinfo(access_token: "access-token", refresh_token: nil) }.to raise_error(OidcClient::OAuthFailure)
      end
    end

    context "but the refreshed access token fails" do
      it "fails" do
        stub_request(:get, "http://openid-provider/userinfo-endpoint")
          .with(headers: { Authorization: "Bearer new-access-token" })
          .to_return(status: 401)

        expect { client.userinfo(access_token: "access-token", refresh_token: "refresh-token") }.to raise_error(OidcClient::OAuthFailure)
      end
    end
  end

  def stub_oidc_client(client = nil)
    oidc_client = instance_double("OpenIDConnect::Client")

    if client
      allow(client).to receive(:client).and_return(oidc_client)
    else
      # rubocop:disable RSpec/AnyInstance
      allow_any_instance_of(OidcClient).to receive(:client).and_return(oidc_client)
      # rubocop:enable RSpec/AnyInstance
    end

    oidc_client
  end
end
