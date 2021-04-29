RSpec.describe AccountSession do
  let(:user_id) { SecureRandom.hex(10) }
  let(:access_token) { SecureRandom.hex(10) }
  let(:refresh_token) { SecureRandom.hex(10) }
  let(:level_of_authentication) { AccountSession::LOWEST_LEVEL_OF_AUTHENTICATION }
  let(:params) { { user_id: user_id, access_token: access_token, refresh_token: refresh_token, level_of_authentication: level_of_authentication }.compact }

  describe "serialisation / deserialisation" do
    it "round-trips" do
      encoded = described_class.new(session_signing_key: "secret", **params).serialise
      decoded = described_class.deserialise(encoded_session: encoded, session_signing_key: "secret").to_hash

      expect(decoded).to eq(params)
    end

    it "rejects a session signed with a different key" do
      encoded = described_class.new(session_signing_key: "secret", **params).serialise
      decoded = described_class.deserialise(encoded_session: encoded, session_signing_key: "different-secret")

      expect(decoded).to be_nil
    end

    it "returns nil on a missing value" do
      expect(described_class.deserialise(encoded_session: nil, session_signing_key: "secret")).to be_nil
      expect(described_class.deserialise(encoded_session: "", session_signing_key: "secret")).to be_nil
    end

    context "when there isn't a user ID in the header" do
      let(:user_id) { nil }
      let(:user_id_from_userinfo) { "user-id-from-userinfo" }
      let(:userinfo_status) { 200 }

      before do
        stub_oidc_discovery

        stub_request(:get, "http://openid-provider/userinfo-endpoint")
          .to_return(status: userinfo_status, body: { sub: user_id_from_userinfo }.to_json)
      end

      it "queries userinfo for the user ID" do
        expect(described_class.new(session_signing_key: "secret", **params).to_hash).to eq(params.merge(user_id: user_id_from_userinfo))
      end

      it "accepts a legacy unsigned session header, and queries userinfo for the user ID" do
        encoded = "#{Base64.urlsafe_encode64(access_token)}.#{Base64.urlsafe_encode64(refresh_token)}"
        decoded = described_class.deserialise(encoded_session: encoded, session_signing_key: "secret").to_hash

        expect(decoded).to eq(params.merge(user_id: user_id_from_userinfo))
      end

      context "when the userinfo request fails" do
        let(:userinfo_status) { 401 }

        before { stub_request(:post, "http://openid-provider/token-endpoint").to_return(status: 401) }

        it "returns nil" do
          encoded = "#{Base64.urlsafe_encode64(access_token)}.#{Base64.urlsafe_encode64(refresh_token)}"
          expect(described_class.deserialise(encoded_session: encoded, session_signing_key: "secret")).to be_nil
        end
      end
    end

    describe "deserialise_legacy_base64_session" do
      it "returns nil on invalid base64" do
        expect(described_class.deserialise_legacy_base64_session(encoded_session: "?.?", session_signing_key: "secret")).to be_nil
      end

      it "returns nil if there are the wrong number of fragments" do
        expect(described_class.deserialise_legacy_base64_session(encoded_session: Base64.urlsafe_encode64("1"), session_signing_key: "secret")).to be_nil
        expect(described_class.deserialise_legacy_base64_session(encoded_session: Base64.urlsafe_encode64("1") + "." + Base64.urlsafe_encode64("2") + "." + Base64.urlsafe_encode64("3"), session_signing_key: "secret")).to be_nil
      end
    end
  end

  describe "user" do
    let(:account_session) { described_class.new(session_signing_key: "key", **params) }

    it "returns a user with the same 'sub' as the session" do
      expect(account_session.user.sub).to eq(account_session.user_id)
    end

    it "creates a user record if one does not exist" do
      expect { account_session.user }.to change(OidcUser, :count)
    end

    it "re-uses a user record if one does exist" do
      current_user = account_session.user
      expect { account_session.user }.not_to change(OidcUser, :count)
      expect(account_session.user.id).to eq(current_user.id)
    end
  end

  describe "local attributes" do
    let(:account_session) { described_class.new(session_signing_key: "key", **params) }

    it "handles an empty list of attributes" do
      expect { account_session.set_local_attributes({}) }.not_to change(LocalAttribute, :count)
    end

    it "round-trips complex local attributes" do
      local_attributes = { "foo" => %w[list of words], "bar" => { "some" => { "nested" => ["thing", 1, 2, 3] } } }

      expect { account_session.set_local_attributes(local_attributes) }.to change(LocalAttribute, :count)
      expect(account_session.get_local_attributes(local_attributes.keys)).to eq(local_attributes)
    end
  end

  describe "OAuth" do
    before { stub_oidc_discovery }

    let(:account_session) { described_class.new(session_signing_key: "key", **params) }

    let(:attribute_name1) { "foo" }
    let(:attribute_name2) { "bar" }
    let(:attribute_value1) { { "some" => "complex", "value" => 42 } }
    let(:attribute_value2) { [1, 2, 3, 4, 5] }

    it "throws an error if making an OAuth call after serialising the session" do
      account_session.serialise
      expect { account_session.get_remote_attributes(%w[foo bar]) }.to raise_error(AccountSession::Frozen)
    end

    describe "get_remote_attributes" do
      before do
        stub_request(:get, "http://openid-provider/v1/attributes/#{attribute_name1}")
          .to_return(status: status, body: { claim_value: attribute_value1 }.compact.to_json)
        stub_request(:get, "http://openid-provider/v1/attributes/#{attribute_name2}")
          .to_return(status: 200, body: { claim_value: attribute_value2 }.compact.to_json)
      end

      let(:status) { 200 }

      it "returns the attributes" do
        expect(account_session.get_remote_attributes([attribute_name1, attribute_name2])).to eq({ attribute_name1 => attribute_value1, attribute_name2 => attribute_value2 })
      end

      context "when some attributes are not found" do
        let(:status) { 404 }

        it "returns no value" do
          expect(account_session.get_remote_attributes([attribute_name1, attribute_name2])).to eq({ attribute_name1 => nil, attribute_name2 => attribute_value2 })
        end
      end
    end

    describe "set_remote_attributes" do
      let(:attributes) { { attribute_name1 => attribute_value1, attribute_name2 => attribute_value2 } }

      it "calls the attribute service" do
        stub = stub_request(:post, "http://openid-provider/v1/attributes")
          .with(body: { attributes: attributes.transform_values(&:to_json) })
          .to_return(status: 200)

        account_session.set_remote_attributes attributes
        expect(stub).to have_been_made
      end

      context "when there are no attributes" do
        it "doesn't call the attribute service" do
          stub = stub_request(:post, "http://openid-provider/v1/attributes")
            .with(body: { attributes: {} })
            .to_return(status: 200)

          account_session.set_remote_attributes({})
          expect(stub).not_to have_been_made
        end
      end
    end

    describe "has_email_subscription?" do
      before do
        stub_request(:get, Plek.find("account-manager") + "/api/v1/transition-checker/email-subscription").to_return(status: status)
      end

      let(:status) { 204 }

      it "returns 'true'" do
        expect(account_session.has_email_subscription?).to be(true)
      end

      context "when the user has a deactivated email subscription" do
        let(:status) { 410 }

        it "returns 'false'" do
          expect(account_session.has_email_subscription?).to be(false)
        end
      end

      context "when the user does not have an email subscription" do
        let(:status) { 404 }

        it "returns 'false'" do
          expect(account_session.has_email_subscription?).to be(false)
        end
      end
    end

    describe "set_email_subscription" do
      let(:slug) { "email-topic-slug" }

      it "calls the account manager" do
        stub = stub_request(:post, Plek.find("account-manager") + "/api/v1/transition-checker/email-subscription")
          .with(body: hash_including(topic_slug: slug))
          .to_return(status: 200)

        account_session.set_email_subscription slug
        expect(stub).to have_been_made
      end
    end
  end
end
