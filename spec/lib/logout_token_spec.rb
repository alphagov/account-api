RSpec.describe LogoutToken do
  let(:klass) { described_class }
  let(:logout_token) { klass.new attributes }
  let(:attributes)  { required_attributes }
  let(:ext)         { 10.minutes.from_now }
  let(:iat)         { Time.zone.now.advance(minutes: -5) }
  let(:jti)         { "bWJq" }
  let(:sid)         { SecureRandom.uuid }
  let(:client_id)   { "client_id" }
  let(:logout_event_name) { "http://schemas.openid.net/event/backchannel-logout" }
  let(:jwt_signing_key) { "secret" }
  let(:signed_jwt) { JSON::JWT.new(required_attributes).sign(jwt_signing_key).to_s }
  let(:required_attributes) do
    {
      iss: "https://server.example.com",
      sub: "user_id",
      aud: client_id,
      iat: iat,
      sid: sid,
      events: {
        logout_event_name => {},
      }.to_json,
      jti: jti,
    }
  end

  let(:required_attribute_keys) { %i[iss aud iat jti events] }
  let(:optional_attribute_keys) { %i[sub sid auth_time] }

  before { Redis.current.flushdb }

  describe "attributes" do
    it "validates required attributes" do
      expect(logout_token.required_attributes).to eq(required_attribute_keys)
    end

    it "stores optional attributes" do
      expect(logout_token.optional_attributes).to eq(optional_attribute_keys)
    end

    describe "auth_time" do
      context "when Time object given" do
        let(:attributes) do
          required_attributes.merge(auth_time: Time.zone.now)
        end

        it "is numeric" do
          expect(logout_token.auth_time).to be_a Numeric
        end
      end
    end

    describe "issued at time" do
      context "when an issued at time (iat) object given" do
        let(:attributes) do
          required_attributes.merge(iat: "1471566154")
        end

        it "is a Time with Zone" do
          expect(logout_token.iat).to be_a ActiveSupport::TimeWithZone
        end
      end
    end
  end

  describe "#verify!" do
    context "when passed a valid token" do
      it "returns true" do
        expect(logout_token.verify!(
                 issuer: attributes[:iss],
                 client_id: attributes[:aud],
               )).to be true
      end

      context "when aud(ience) is an array of identifiers" do
        let(:client_id) { "client_id" }
        let(:attributes) { required_attributes.merge(aud: ["some_other_identifier", client_id]) }

        it "returns true" do
          expect(logout_token.verify!(
                   issuer: attributes[:iss],
                   client_id: attributes[:aud].last,
                 )).to be true
        end
      end
    end

    context "when issuer is invalid" do
      it "raises an error" do
        expect {
          logout_token.verify!(
            issuer: "invalid_issuer",
            client_id: attributes[:aud],
          )
        }.to raise_error LogoutToken::InvalidToken
      end
    end

    context "when issuer is missing" do
      it "raises an error" do
        expect {
          logout_token.verify!(
            client_id: attributes[:aud],
          )
        }.to raise_error LogoutToken::InvalidToken
      end
    end

    context "when client_id is invalid" do
      it "raises an error" do
        expect {
          logout_token.verify!(
            issuer: attributes[:iss],
            client_id: "invalid_client",
          )
        }.to raise_error LogoutToken::InvalidToken
      end
    end

    context "when client_id is missing" do
      it "raises an error" do
        expect {
          logout_token.verify!(
            issuer: attributes[:iss],
          )
        }.to raise_error LogoutToken::InvalidToken
      end
    end

    context "when issued at time is in the future" do
      let(:attributes) { required_attributes.merge(iat: Time.zone.now.advance(minutes: 5).strftime("%s")) }

      it "raises an error" do
        expect {
          logout_token.verify!(
            issuer: attributes[:iss],
            client_id: attributes[:aud],
          )
        }.to raise_error LogoutToken::InvalidToken
      end
    end

    context "when sub and sid are missing" do
      let(:attributes) { required_attributes.reject { |k, _v| %i[sub sid].include?(k) } }

      it "raises an error" do
        expect {
          logout_token.verify!(
            issuer: attributes[:iss],
            client_id: attributes[:aud],
          )
        }.to raise_error LogoutToken::InvalidToken
      end
    end

    context "when events claim does not include backchannel logout event" do
      let(:attributes) { required_attributes.merge(events: {}.to_json) }

      it "raises an error" do
        expect {
          logout_token.verify!(
            issuer: attributes[:iss],
            client_id: attributes[:aud],
          )
        }.to raise_error LogoutToken::InvalidToken
      end
    end

    context "when events claim back channel logout event is not an empty hash" do
      let(:attributes) { required_attributes.merge(events: { logout_event_name => { "empty" => false } }.to_json) }

      it "raises an error" do
        expect {
          logout_token.verify!(
            issuer: attributes[:iss],
            client_id: attributes[:aud],
          )
        }.to raise_error LogoutToken::InvalidToken
      end
    end

    context "when nonse is given" do
      let(:attributes)  { required_attributes.merge(nonse: "nonse") }

      it "raises an error" do
        expect {
          logout_token.verify!(
            issuer: attributes[:iss],
            client_id: attributes[:aud],
          )
        }.to raise_error LogoutToken::ProhibitedNonse
      end
    end

    context "when a JTI is already in the cache" do
      it "raises an error" do
        Redis.current.set("logout-token/#{jti}", "OK")
        Redis.current.expire("logout-token/#{jti}", 2.minutes)
        expect {
          logout_token.verify!(
            issuer: attributes[:iss],
            client_id: attributes[:aud],
          )
        }.to raise_error LogoutToken::TokenRecentlyUsed
      end
    end
  end

  describe "LogoutToken.decode" do
    it "decodes a signed JWT with a valid signing key" do
      expect(LogoutToken.decode(signed_jwt, jwt_signing_key)).to be_a LogoutToken
    end

    it "raises an error if verification fails" do
      expect {
        LogoutToken.decode(signed_jwt, "wrong")
      }.to raise_error JSON::JWS::VerificationFailed
    end
  end
end
