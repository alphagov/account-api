RSpec.describe TransitionCheckerEmailSubscriptionController do
  before do
    stub_oidc_discovery

    # rubocop:disable RSpec/AnyInstance
    allow_any_instance_of(OidcClient).to receive(:tokens!).and_return({ access_token: "access-token", refresh_token: "refresh-token" })
    # rubocop:enable RSpec/AnyInstance
  end

  let(:headers) { { "GOVUK-Account-Session" => placeholder_govuk_account_session } }

  describe "GET" do
    before do
      stub_request(:get, Plek.find("account-manager") + "/api/v1/transition-checker/email-subscription").to_return(status: status)
    end

    let(:status) { 500 }

    context "when the user has an email subscription" do
      let(:status) { 204 }

      it "returns 'true'" do
        get transition_checker_email_subscription_path, headers: headers
        expect(response).to be_successful
        expect(JSON.parse(response.body)["has_subscription"]).to be(true)
      end
    end

    context "when the user has a deactivated email subscription" do
      let(:status) { 410 }

      it "returns 'false'" do
        get transition_checker_email_subscription_path, headers: headers
        expect(response).to be_successful
        expect(JSON.parse(response.body)["has_subscription"]).to be(false)
      end
    end

    context "when the user does not have an email subscription" do
      let(:status) { 404 }

      it "returns 'false'" do
        get transition_checker_email_subscription_path, headers: headers
        expect(response).to be_successful
        expect(JSON.parse(response.body)["has_subscription"]).to be(false)
      end
    end

    context "when the tokens are rejected" do
      before { stub_request(:post, "http://openid-provider/token-endpoint").to_return(status: 401) }

      let(:status) { 401 }

      it "returns a 401" do
        get transition_checker_email_subscription_path, headers: headers
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when no govuk-account-session is provided" do
      it "returns a 401" do
        get transition_checker_email_subscription_path
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST" do
    it "calls the account manager" do
      stub = stub_request(:post, Plek.find("account-manager") + "/api/v1/transition-checker/email-subscription")
        .with(body: hash_including(topic_slug: "slug"))
        .to_return(status: 200)

      post transition_checker_email_subscription_path, headers: headers, params: { slug: "slug" }
      expect(response).to be_successful
      expect(stub).to have_been_made
    end

    context "when the tokens are rejected" do
      before { stub_request(:post, "http://openid-provider/token-endpoint").to_return(status: 401) }

      it "returns a 401" do
        stub_request(:post, Plek.find("account-manager") + "/api/v1/transition-checker/email-subscription")
          .with(body: hash_including(topic_slug: "slug"))
          .to_return(status: 401)

        post transition_checker_email_subscription_path, headers: headers, params: { slug: "slug" }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when no govuk-account-session is provided" do
      it "returns a 401" do
        post transition_checker_email_subscription_path
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
