RSpec.describe AccountSession do
  before { stub_oidc_discovery }

  let(:id_token) { SecureRandom.hex(10) }
  let(:user_id) { SecureRandom.hex(10) }
  let(:access_token) { SecureRandom.hex(10) }
  let(:refresh_token) { SecureRandom.hex(10) }
  let(:mfa) { false }
  let(:version) { 1 }
  let(:params) do
    {
      id_token: id_token,
      user_id: user_id,
      access_token: access_token,
      refresh_token: refresh_token,
      mfa: mfa,
      digital_identity_session: true,
      version: version,
    }.compact
  end

  let(:account_session) { described_class.new(session_secret: "key", **params) }

  it "throws an error if making an OAuth call after serialising the session" do
    account_session.serialise
    expect { account_session.send(:userinfo) }.to raise_error(AccountSession::Frozen)
  end

  context "when the session version is not a known version" do
    let(:version) { -1 }

    it "throws an error" do
      expect { described_class.new(session_secret: "secret", **params) }.to raise_error(AccountSession::SessionVersionInvalid)
    end
  end

  context "when the session version is nil" do
    let(:version) { nil }

    it "upgrades session to the current version" do
      session = described_class.new(session_secret: "secret", **params)
      expect(session.to_hash[:version]).to eq(AccountSession::CURRENT_VERSION)
    end
  end

  describe "serialisation / deserialisation" do
    it "round-trips" do
      encoded = described_class.new(session_secret: "secret", **params).serialise
      decoded = described_class.deserialise(encoded_session: encoded, session_secret: "secret").to_hash

      expect(decoded).to eq(params)
    end

    it "decodes successfully in the presence of flash messages" do
      encoded = described_class.new(session_secret: "secret", **params).serialise
      decoded = described_class.deserialise(encoded_session: "#{encoded}$$some,flash,keys", session_secret: "secret")
      expect(decoded).not_to be_nil
      expect(decoded.to_hash).to eq(params)
    end

    it "rejects a session signed with a different key" do
      encoded = described_class.new(session_secret: "secret", **params).serialise
      decoded = described_class.deserialise(encoded_session: encoded, session_secret: "different-secret")
      expect(decoded).to be_nil
    end

    it "returns nil on a missing value" do
      expect(described_class.deserialise(encoded_session: nil, session_secret: "secret")).to be_nil
      expect(described_class.deserialise(encoded_session: "", session_secret: "secret")).to be_nil
    end

    context "when there is a level of authentication, not an mfa flag, in the header and there is no version" do
      let(:mfa) { nil }
      let(:version) { nil }

      it "decodes level0 to mfa: false" do
        encoded = StringEncryptor.new(secret: "secret").encrypt_string(params.merge(level_of_authentication: "level0").to_json)
        expect(described_class.deserialise(encoded_session: encoded, session_secret: "secret").mfa?).to be(false)
      end

      it "decodes level1 to mfa: true" do
        encoded = StringEncryptor.new(secret: "secret").encrypt_string(params.merge(level_of_authentication: "level1").to_json)
        expect(described_class.deserialise(encoded_session: encoded, session_secret: "secret").mfa?).to be(true)
      end
    end

    context "when there isn't an ID token in the header" do
      let(:id_token) { nil }
      let(:encoded) { StringEncryptor.new(secret: "secret").encrypt_string(params.to_json) }

      it "successfully decodes with a nil token value" do
        expect(described_class.deserialise(encoded_session: encoded, session_secret: "secret").to_hash).to eq(params.merge(id_token: nil))
      end
    end

    context "when there isn't a user ID in the header and no version" do
      let(:encoded) { StringEncryptor.new(secret: "secret").encrypt_string(params.to_json) }
      let(:user_id) { nil }
      let(:user_id_from_userinfo) { "user-id-from-userinfo" }
      let(:userinfo_status) { 200 }
      let(:version) { nil }

      before do
        stub_request(:get, "http://openid-provider/userinfo-endpoint")
          .to_return(status: userinfo_status, body: { sub: user_id_from_userinfo }.to_json)
      end

      it "queries userinfo for the user ID" do
        expect(described_class.deserialise(encoded_session: encoded, session_secret: "secret").to_hash).to eq(params.merge(user_id: user_id_from_userinfo, version: 1))
      end

      context "when the userinfo request fails" do
        let(:userinfo_status) { 401 }

        before { stub_request(:post, "http://openid-provider/token-endpoint").to_return(status: 401) }

        it "returns nil" do
          expect(described_class.deserialise(encoded_session: encoded, session_secret: "secret")).to be_nil
        end
      end
    end
  end

  describe "user" do
    it "returns a user with the same 'sub' as the session" do
      expect(account_session.user.sub).to eq(account_session.user_id)
    end

    it "creates a user record if one does not exist" do
      expect { account_session.user }.to change(OidcUser, :count).by(1)
    end

    it "re-uses a user record if one does exist" do
      current_user = account_session.user
      expect { account_session.user }.not_to change(OidcUser, :count)
      expect(account_session.user.id).to eq(current_user.id)
    end
  end

  describe "attributes" do
    let(:cached_attribute_name) { "email" }
    let(:local_attribute_name) { "transition_checker_state" }
    let(:local_attribute_value) { [1, 2, { "buckle" => %w[my shoe] }] }

    describe "get_attributes" do
      before { stub_userinfo }

      it "returns no values" do
        expect(account_session.get_attributes([cached_attribute_name])).to eq({})
      end

      it "handles the 'has_unconfirmed_email' attribute as a special case" do
        expect(account_session.get_attributes(%w[has_unconfirmed_email])).to eq({ "has_unconfirmed_email" => false })
      end

      context "when the attribute value is in the userinfo response" do
        before do
          stub_userinfo(cached_attribute_name => value_from_userinfo)
        end

        let(:value_from_userinfo) { "value-from-userinfo" }

        it "uses the value from the userinfo response" do
          expect(account_session.get_attributes([cached_attribute_name])).to eq({ cached_attribute_name => value_from_userinfo })
        end

        it "stores the value locally" do
          account_session.get_attributes([cached_attribute_name])
          expect(account_session.user[cached_attribute_name]).to eq(value_from_userinfo)
        end
      end
    end

    describe "set_attributes" do
      it "saves attributes to the database" do
        account_session.set_attributes(local_attribute_name => local_attribute_value)
        expect(account_session.user[local_attribute_name]).to eq(local_attribute_value)
      end
    end
  end
end
