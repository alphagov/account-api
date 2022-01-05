RSpec.describe OidcClient::Fake do
  subject(:client) { described_class.new }

  describe "auth_uri" do
    it "includes code=without-mfa when MFA is not required" do
      expect(client.auth_uri(AuthRequest.generate!, mfa: false)).to include("code=without-mfa")
    end

    it "includes code=with-mfa when MFA is required" do
      expect(client.auth_uri(AuthRequest.generate!, mfa: true)).to include("code=with-mfa")
    end
  end

  describe "callback" do
    it "creates a user when there is no user in the database" do
      expect { client.callback(AuthRequest.generate!, "without-mfa") }.to change(OidcUser, :count).by(1)
    end

    context "when there are users" do
      before { FactoryBot.create_list(:oidc_user, 3) }

      it "returns tokens for the first user in the database" do
        expect(client.callback(AuthRequest.generate!, "without-mfa")[:id_token].sub).to eq(OidcUser.first.sub)
      end

      it "returns a no-MFA session if the code is 'without-mfa'" do
        expect(client.callback(AuthRequest.generate!, "without-mfa")[:mfa]).to be(false)
      end

      it "returns an MFA session if the code is 'with-mfa'" do
        expect(client.callback(AuthRequest.generate!, "with-mfa")[:mfa]).to be(true)
      end
    end
  end

  describe "tokens!" do
    it "creates a user when there is no user in the database" do
      expect { client.tokens! }.to change(OidcUser, :count).by(1)
    end

    context "when there are users" do
      before { FactoryBot.create_list(:oidc_user, 3) }

      it "uses the subject identifier of the first user in the database as the access token" do
        expect(client.tokens![:access_token]).to eq(OidcUser.first.sub)
      end

      it "doesn't generate an ID token by default" do
        expect(client.tokens![:id_token]).to be_nil
      end

      it "generates an ID token for the first user in the database if a nonce is provided" do
        expect(client.tokens!(oidc_nonce: "nonce")[:id_token].sub).to eq(OidcUser.first.sub)
      end
    end
  end

  describe "userinfo" do
    let(:user) { FactoryBot.create(:oidc_user) }
    let(:access_token) { user.sub }

    it "treats the access token as a subject identifier and generates userinfo" do
      userinfo = {
        "sub" => user.sub,
        "email" => user.email || "email@example.com",
        "email_verified" => user.email_verified || false,
      }

      expect(client.userinfo(access_token: access_token)).to eq(userinfo)
    end

    it "throws an error if the access token doesn't correspond to a user" do
      expect { client.userinfo(access_token: "access-token") }.to raise_error(OidcClient::Fake::NoDevelopmentUser)
    end
  end
end
