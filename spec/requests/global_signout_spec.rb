RSpec.describe "Global Signout endpoint" do
  let(:issuer) { "identity-provider" }
  let(:subject_identifier) { "subject-identifier" }
  let(:audience) { "relaying_party_client_id" }
  let(:issued_at_time) { Time.zone.now.advance(minutes: -5).to_i }
  let(:unique_token) { Array.new(5) { (("a".."z").to_a + ("A".."Z").to_a).sample }.join }
  let(:session_identifier) { SecureRandom.uuid }
  let(:events) do
    {
      "http://schemas.openid.net/event/backchannel-logout": {},
    }
  end

  let(:payload) do
    {
      "iss" => issuer,
      "sub" => subject_identifier,
      "aud" => audience,
      "iat" => issued_at_time,
      "jti" => unique_token,
      "sid" => session_identifier,
      "events" => events,
    }
  end

  let(:params) do
    {
      logout_token: "token",
    }
  end

  describe "POST" do
    context "with an invalid logout token" do
      it "returns 400 if the logout token cannot verify the signature"
      it "returns 400 if the logout token is badly formatted"
    end

    context "with a valid logout token" do
      it "records a session expiry notice"
      it "it returns 200" do
        post backchannel_logout_path, params: {logout_token: "foo"}
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
