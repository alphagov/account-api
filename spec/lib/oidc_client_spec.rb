RSpec.describe OidcClient do
  subject(:client) { described_class.new }

  before { stub_oidc_discovery }

  describe "auth_uri" do
    it "includes vtr=['Cl','Cl.Cm'] when MFA is not required" do
      expect(client.auth_uri(AuthRequest.generate!, mfa: false)).to include(Rack::Utils.escape('["Cl","Cl.Cm"]'))
    end

    it "includes vtr=['Cl.Cm'] when MFA is required" do
      expect(client.auth_uri(AuthRequest.generate!, mfa: true)).to include(Rack::Utils.escape('["Cl.Cm"]'))
    end
  end

  describe "callback" do
    before { stub_token_response }

    it "calls userinfo to fetch the legacy sub and creates the user model" do
      stub = stub_request(:get, "http://openid-provider/userinfo-endpoint")
        .with(headers: { Authorization: "Bearer access-token" })
        .to_return(status: 200, body: { "legacy_subject_id" => "legacy-sub" }.to_json)

      expect { client.callback(AuthRequest.generate!, "code") }.to change(OidcUser, :count).by(1)

      expect(stub).to have_been_made
      expect(OidcUser.find_by(sub: "user-id", legacy_sub: "legacy-sub")).not_to be_nil
    end

    context "when the user exists with the legacy sub" do
      let!(:user) { FactoryBot.create(:oidc_user, sub: "legacy-sub", legacy_sub: "legacy-sub") }

      it "calls userinfo to fetch the legacy sub and updates the user model" do
        stub = stub_request(:get, "http://openid-provider/userinfo-endpoint")
          .with(headers: { Authorization: "Bearer access-token" })
          .to_return(status: 200, body: { "legacy_subject_id" => "legacy-sub" }.to_json)

        expect { client.callback(AuthRequest.generate!, "code") }.not_to change(OidcUser, :count)

        expect(stub).to have_been_made
        expect(user.reload.sub).to eq("user-id")
        expect(user.reload.legacy_sub).to eq("legacy-sub")
      end
    end

    context "when the user exists with the current sub" do
      before { FactoryBot.create(:oidc_user, sub: "user-id", legacy_sub: "legacy-sub") }

      it "does not call userinfo" do
        stub = stub_request(:get, "http://openid-provider/userinfo-endpoint")
          .with(headers: { Authorization: "Bearer access-token" })
          .to_return(status: 200, body: { "legacy_subject_id" => "legacy-sub" }.to_json)

        expect { client.callback(AuthRequest.generate!, "code") }.not_to change(OidcUser, :count)

        expect(stub).not_to have_been_made
      end
    end
  end

  describe "tokens!" do
    before do
      access_token = Rack::OAuth2::AccessToken.new(
        access_token: "access-token",
        token_type: "test",
      )

      @client_stub = stub_oidc_client(client)
      # rubocop:disable RSpec/InstanceVariable
      allow(@client_stub).to receive(:access_token!).and_return(access_token)
      # rubocop:enable RSpec/InstanceVariable
    end

    it "doesn't fetch an ID token by default" do
      expect(client.tokens!).to eq({ access_token: "access-token" })
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

  describe "retrying OAuth requests" do
    shared_examples "the initial request fails" do
      before do
        stub = stub_request(:get, "http://openid-provider/userinfo-endpoint")
          .with(headers: { Authorization: "Bearer access-token" })
        setup_failure stub
      end

      it "retries" do
        stub_request(:get, "http://openid-provider/userinfo-endpoint")
          .with(headers: { Authorization: "Bearer access-token" })
          .to_return(status: 200, body: { id: "foo" }.to_json)

        expect(client.userinfo(access_token: "access-token"))
          .to eq({ "id" => "foo" })
      end

      context "but it fails again" do
        before do
          stub = stub_request(:get, "http://openid-provider/userinfo-endpoint")
            .with(headers: { Authorization: "Bearer access-token" })
          setup_failure stub
        end

        it "fails" do
          expect { client.userinfo(access_token: "access-token") }.to raise_error(OidcClient::OAuthFailure)
        end
      end
    end

    describe "there is a networking issue" do
      include_examples "the initial request fails"

      def setup_failure(stub)
        stub.to_raise(Errno::ECONNRESET)
      end
    end

    describe "the OAuth provider returns a server error" do
      include_examples "the initial request fails"

      def setup_failure(stub)
        stub.to_return(status: 504)
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
