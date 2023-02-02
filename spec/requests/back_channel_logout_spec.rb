RSpec.describe "OIDC Backchannel Logout" do
  let(:logout_token_jwt) { "pretend_this_is_a_jwt" }
  let(:sub) { "user_id " }

  let(:params) do
    { logout_token: logout_token_jwt }
  end

  let(:oidc_client_logout_token) do
    {
      logout_token_jwt:,
      logout_token:,
      request_time: Time.zone.now,
    }
  end

  let(:oidc_client) { instance_double(OidcClient) }
  let(:logout_token) { instance_double(LogoutToken) }
  let(:redis_formatted_time) { Time.zone.now.strftime("%F %T %z") }

  before do
    allow(OidcClient).to receive(:new).and_return(oidc_client)
    allow(oidc_client).to receive(:logout_token).and_return(oidc_client_logout_token)
    allow(logout_token).to receive(:sub).and_return(sub)
    freeze_time
    Redis.new.flushdb
  end

  describe "POST" do
    context "with an token that is unverifiable" do
      before do
        allow(oidc_client).to receive(:logout_token).and_raise(OidcClient::BackchannelLogoutFailure)
      end

      it "returns 400" do
        post(backchannel_logout_path, params:)
        expect(response).to have_http_status(:bad_request)
      end
    end

    context "with a valid logout token" do
      it "records a session expiry notice" do
        post(backchannel_logout_path, params:)
        expect(Redis.new.get("logout-notice/#{sub}")).to eq(redis_formatted_time)
      end

      it "returns 200" do
        post(backchannel_logout_path, params:)
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
