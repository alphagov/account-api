RSpec.describe AccountSession do
  before do
    stub_oidc_discovery

    fixture_file = YAML.safe_load(File.read(Rails.root.join("spec/fixtures/user_attributes.yml"))).with_indifferent_access
    allow(UserAttributes).to receive(:load_config_file).and_return(fixture_file)
  end

  let(:user_id) { SecureRandom.hex(10) }
  let(:access_token) { SecureRandom.hex(10) }
  let(:refresh_token) { SecureRandom.hex(10) }
  let(:level_of_authentication) { AccountSession::LOWEST_LEVEL_OF_AUTHENTICATION }
  let(:params) { { user_id: user_id, access_token: access_token, refresh_token: refresh_token, level_of_authentication: level_of_authentication }.compact }
  let(:account_session) { described_class.new(session_signing_key: "key", **params) }

  it "throws an error if making an OAuth call after serialising the session" do
    account_session.serialise
    expect { account_session.get_attributes(%w[foo bar]) }.to raise_error(AccountSession::Frozen)
  end

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
        stub_request(:get, "http://openid-provider/userinfo-endpoint")
          .to_return(status: userinfo_status, body: { sub: user_id_from_userinfo }.to_json)
      end

      it "queries userinfo for the user ID" do
        expect(described_class.new(session_signing_key: "secret", **params).to_hash).to eq(params.merge(user_id: user_id_from_userinfo))
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
    let(:attribute_name1) { "test_attribute_1" }
    let(:attribute_name2) { "test_attribute_2" }
    let(:local_attribute_name) { "test_local_attribute" }
    let(:attribute_value1) { { "some" => "complex", "value" => 42 } }
    let(:attribute_value2) { [1, 2, 3, 4, 5] }
    let(:local_attribute_value) { [1, 2, { "buckle" => %w[my shoe] }] }

    describe "get_attributes" do
      before do
        stub_userinfo
        stub_request(:get, "http://openid-provider/v1/attributes/#{attribute_name1}")
          .to_return(status: status, body: { claim_value: attribute_value1 }.compact.to_json)
        stub_request(:get, "http://openid-provider/v1/attributes/#{attribute_name2}")
          .to_return(status: 200, body: { claim_value: attribute_value2 }.compact.to_json)
      end

      let(:status) { 200 }

      it "returns the attributes" do
        LocalAttribute.create!(
          oidc_user: OidcUser.find_or_create_by(sub: user_id),
          name: local_attribute_name,
          value: local_attribute_value,
        )

        values = account_session.get_attributes([attribute_name1, attribute_name2, local_attribute_name])
        expect(values).to eq({ attribute_name1 => attribute_value1, attribute_name2 => attribute_value2, local_attribute_name => local_attribute_value })
      end

      context "when the attribute value is in the userinfo response" do
        before do
          stub_userinfo(attribute_name1 => value_from_userinfo)
        end

        let(:value_from_userinfo) { "value-from-userinfo" }

        it "uses the value from the userinfo response" do
          expect(account_session.get_attributes([attribute_name1])).to eq({ attribute_name1 => value_from_userinfo })
        end
      end

      context "when some attributes are not found" do
        let(:status) { 404 }

        it "returns no value" do
          expect(account_session.get_attributes([attribute_name1, attribute_name2])).to eq({ attribute_name2 => attribute_value2 })
        end
      end

      context "when an attribute is cached_locally" do
        let(:attribute_name1) { "test_attribute_cache" }

        it "fetches the attribute and stores it locally" do
          expect { account_session.get_attributes([attribute_name1]) }.to change(LocalAttribute, :count).by(1)
          expect(account_session.get_attributes([attribute_name1])).to eq({ attribute_name1 => attribute_value1 })
        end

        context "when the attribute is unset" do
          let(:attribute_value1) { nil }

          it "does not try to cache locally" do
            expect { account_session.get_attributes([attribute_name1]) }.not_to change(LocalAttribute, :count)
            expect(account_session.get_attributes([attribute_name1])).to eq({})
          end
        end
      end
    end

    describe "set_attributes" do
      let(:remote_attributes) { { attribute_name1 => attribute_value1, attribute_name2 => attribute_value2 } }
      let(:local_attributes) { { local_attribute_name => local_attribute_value } }
      let(:attributes) { remote_attributes.merge(local_attributes) }

      it "calls the attribute service for remote attributes, calls the database for local attributes" do
        stub = stub_set_remote_attributes
        expect { account_session.set_attributes(attributes) }.to change(LocalAttribute, :count).by(1)
        expect(stub).to have_been_made
      end

      context "when the local attribute already exists" do
        it "increases the updated_at time" do
          attribute = LocalAttribute.create!(
            oidc_user: OidcUser.find_or_create_by(sub: user_id),
            name: local_attribute_name,
            value: local_attribute_value,
          )

          expect { account_session.set_attributes(local_attributes) }.to(change { attribute.reload.updated_at })
        end
      end

      context "when there are no local attributes" do
        let(:local_attributes) { {} }

        it "doesn't update the database" do
          stub = stub_set_remote_attributes
          expect { account_session.set_attributes(attributes) }.not_to change(LocalAttribute, :count)
          expect(stub).to have_been_made
        end
      end

      context "when there are no remote attributes" do
        let(:remote_attributes) { {} }

        it "doesn't call the attribute service" do
          stub = stub_set_remote_attributes
          account_session.set_attributes(attributes)
          expect(stub).not_to have_been_made
        end
      end

      context "when an attribute is cached_locally" do
        let(:attribute_name1) { "test_attribute_cache" }
        let(:remote_attributes) { { attribute_name1 => attribute_value1 } }
        let(:local_attributes) { {} }

        it "sets the attribute both locally and remotely" do
          stub = stub_set_remote_attributes
          expect { account_session.set_attributes(attributes) }.to change(LocalAttribute, :count).by(1)
          expect(stub).to have_been_made
        end
      end

      def stub_set_remote_attributes
        stub_request(:post, "http://openid-provider/v1/attributes")
          .with(body: { attributes: remote_attributes.transform_values(&:to_json) })
          .to_return(status: 200)
      end
    end
  end
end
