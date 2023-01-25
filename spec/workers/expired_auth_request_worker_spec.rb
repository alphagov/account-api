RSpec.describe ExpiredAuthRequestWorker do
  before { freeze_time }

  it "deletes old state" do
    AuthRequest.create!(oauth_state: "foo", oidc_nonce: "bar", redirect_path: "/some-path", created_at: (AuthRequest::EXPIRATION_AGE + 1.second).ago)
    expect { described_class.new.perform }.to change(AuthRequest, :count).to(0)
  end

  it "doesn't delete recent state" do
    AuthRequest.create!(oauth_state: "foo", oidc_nonce: "bar", redirect_path: "/some-path", created_at: AuthRequest::EXPIRATION_AGE.ago)
    expect { described_class.new.perform }.not_to change(AuthRequest, :count)
  end
end
