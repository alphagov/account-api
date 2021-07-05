RSpec.describe "Transition Checker email subscriptions" do
  before do
    stub_oidc_discovery

    # rubocop:disable RSpec/AnyInstance
    allow_any_instance_of(OidcClient).to receive(:tokens!).and_return({ access_token: "access-token", refresh_token: "refresh-token" })
    # rubocop:enable RSpec/AnyInstance
  end

  let(:headers) { { "Content-Type" => "application/json", "GOVUK-Account-Session" => session_identifier } }
  let(:session_identifier) { placeholder_govuk_account_session(level_of_authentication: "level1") }

  describe "GET" do
    before do
      stub_request(:get, "#{Plek.find('account-manager')}/api/v1/transition-checker/email-subscription").to_return(status: status, body: body)
    end

    let(:status) { 500 }
    let(:body) { nil }

    context "when the user has an email subscription" do
      let(:status) { 200 }
      let(:body) { { topic_slug: "topic", subscription_id: "id" }.to_json }

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

    context "when the user doesn't have a high enough level of authentication" do
      let(:session_identifier) { placeholder_govuk_account_session(level_of_authentication: "level-1") }

      it "returns a 403 and the required level" do
        get transition_checker_email_subscription_path, headers: headers
        expect(response).to have_http_status(:forbidden)

        error = JSON.parse(response.body)
        expect(error["type"]).to eq(I18n.t("errors.level_of_authentication_too_low.type"))
        expect(error["attributes"]).to eq(%w[transition_checker_state])
        expect(error["needed_level_of_authentication"]).to eq("level0")
      end
    end
  end

  describe "POST" do
    it "calls the account manager" do
      stub = stub_request(:post, "#{Plek.find('account-manager')}/api/v1/transition-checker/email-subscription")
        .with(body: hash_including(topic_slug: "slug"))
        .to_return(status: 200)

      post transition_checker_email_subscription_path, headers: headers, params: { slug: "slug" }.to_json
      expect(response).to be_successful
      expect(stub).to have_been_made
    end

    context "when the tokens are rejected" do
      before { stub_request(:post, "http://openid-provider/token-endpoint").to_return(status: 401) }

      it "returns a 401" do
        stub_request(:post, "#{Plek.find('account-manager')}/api/v1/transition-checker/email-subscription")
          .with(body: hash_including(topic_slug: "slug"))
          .to_return(status: 401)

        post transition_checker_email_subscription_path, headers: headers, params: { slug: "slug" }.to_json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when no govuk-account-session is provided" do
      it "returns a 401" do
        post transition_checker_email_subscription_path
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when the user doesn't have a high enough level of authentication" do
      let(:session_identifier) { placeholder_govuk_account_session(level_of_authentication: "level-1") }

      it "returns a 403 and the required level" do
        post transition_checker_email_subscription_path, headers: headers, params: { slug: "slug" }.to_json
        expect(response).to have_http_status(:forbidden)

        error = JSON.parse(response.body)
        expect(error["type"]).to eq(I18n.t("errors.level_of_authentication_too_low.type"))
        expect(error["attributes"]).to eq(%w[transition_checker_state])
        expect(error["needed_level_of_authentication"]).to eq("level1")
      end
    end
  end
end
