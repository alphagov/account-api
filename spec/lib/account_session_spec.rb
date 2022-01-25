RSpec.describe AccountSession do
  before { stub_oidc_discovery }

  let(:id_token) { SecureRandom.hex(10) }
  let(:user_id) { SecureRandom.hex(10) }
  let(:mfa) { false }
  let(:version) { AccountSession::CURRENT_VERSION }
  let(:params) do
    {
      id_token: id_token,
      user_id: user_id,
      mfa: mfa,
      digital_identity_session: true,
      version: version,
    }.compact
  end

  let(:account_session) { described_class.new(session_secret: "key", **params) }

  context "when the session is for a user which has been destroyed" do
    before { Tombstone.create!(sub: user_id) }

    it "throws an error" do
      expect { described_class.new(session_secret: "secret", **params) }.to raise_error(AccountSession::UserDestroyed)
    end
  end

  context "when the session version is not a known version" do
    let(:version) { -1 }

    it "throws an error" do
      expect { described_class.new(session_secret: "secret", **params) }.to raise_error(AccountSession::SessionVersionInvalid)
    end
  end

  context "when the session version is nil" do
    let(:version) { nil }

    it "throws an error" do
      expect { described_class.new(session_secret: "secret", **params) }.to raise_error(AccountSession::SessionVersionInvalid)
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
    before do
      account_session.set_attributes(
        cached_attribute_name => cached_attribute_value,
        local_attribute_name => local_attribute_value,
      )
    end

    let(:cached_attribute_name) { "email" }
    let(:cached_attribute_value) { nil }
    let(:local_attribute_name) { "feedback_consent" }
    let(:local_attribute_value) { nil }

    describe "get_attributes" do
      it "throws an exception for a missing cached attribute" do
        expect { account_session.get_attributes([cached_attribute_name]) }.to raise_error(AccountSession::MissingCachedAttribute)
      end

      it "returns nil for a missing local attribute" do
        expect(account_session.get_attributes([local_attribute_name])).to eq({})
      end

      context "when the attribute value is cached" do
        let(:cached_attribute_value) { "email@example.com" }

        it "returns it" do
          expect(account_session.get_attributes([cached_attribute_name])).to eq({ cached_attribute_name => cached_attribute_value })
        end
      end
    end

    describe "set_attributes" do
      let(:local_attribute_value) { true }

      it "saves attributes to the database" do
        account_session.set_attributes(local_attribute_name => local_attribute_value)
        expect(account_session.user[local_attribute_name]).to eq(local_attribute_value)
      end
    end
  end
end
