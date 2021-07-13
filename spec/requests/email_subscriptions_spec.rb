require "gds_api/test_helpers/email_alert_api"

RSpec.describe "Email subscriptions" do
  include GdsApi::TestHelpers::EmailAlertApi

  let(:headers) { { "Content-Type" => "application/json", "GOVUK-Account-Session" => session_identifier.serialise } }
  let(:session_identifier) { placeholder_govuk_account_session_object }

  describe "GET /api/email-subscriptions/:subscription_name" do
    it "returns a 404" do
      get email_subscription_path(subscription_name: "foo"), headers: headers
      expect(response).to have_http_status(:not_found)
    end

    context "when the subscription exists" do
      before do
        stub_email_alert_api_has_subscription(
          email_subscription.email_alert_api_subscription_id,
          "daily",
          ended: subscription_ended,
        )
      end

      let(:email_subscription) do
        FactoryBot.create(:email_subscription, oidc_user: session_identifier.user, email_alert_api_subscription_id: "prior-subscription-id")
      end

      let(:subscription_ended) { false }

      it "returns the subscription details" do
        get email_subscription_path(subscription_name: email_subscription.name), headers: headers
        expect(response).to be_successful
        expect(JSON.parse(response.body)["email_subscription"]).to eq(email_subscription.to_hash)
      end

      context "when the subscription has been ended in email-alert-api" do
        let(:subscription_ended) { true }

        it "deletes the subscription here and returns a 404" do
          stub_email_alert_api_unsubscribes_a_subscription(email_subscription.email_alert_api_subscription_id)
          expect { get email_subscription_path(subscription_name: email_subscription.name), headers: headers }.to change(EmailSubscription, :count).by(-1)
          expect(response).to have_http_status(:not_found)
        end
      end
    end

    context "when it's the transition checker subscription" do
      before do
        stub_oidc_discovery

        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(OidcClient).to receive(:tokens!).and_return({ access_token: "access-token", refresh_token: "refresh-token" })
        # rubocop:enable RSpec/AnyInstance

        stub_email_alert_api_has_subscription(subscription_id, "daily")
      end

      let(:status) { 200 }
      let(:slug) { "slug" }
      let(:subscription_id) { "id" }

      it "calls the account manager and migrates the subscription" do
        stubs = stub_account_manager
        get email_subscription_path(subscription_name: "transition-checker-results"), headers: headers
        expect(stubs[:get]).to have_been_made
        expect(stubs[:delete]).to have_been_made
      end

      it "returns the subscription details" do
        stub_account_manager
        get email_subscription_path(subscription_name: "transition-checker-results"), headers: headers
        expect(response).to be_successful

        response_subscription_details = JSON.parse(response.body)["email_subscription"]
        database_subscription_details = EmailSubscription.where(name: "transition-checker-results").last.to_hash
        expect(response_subscription_details).to eq(database_subscription_details)
      end

      context "when the subscription has already been migrated" do
        before do
          FactoryBot.create(:email_subscription, oidc_user: session_identifier.user, name: "transition-checker-results", topic_slug: "slug")
        end

        it "does not re-migrate it" do
          stubs = stub_account_manager
          get email_subscription_path(subscription_name: "transition-checker-results"), headers: headers
          expect(stubs[:get]).not_to have_been_made
          expect(stubs[:delete]).not_to have_been_made
        end
      end

      context "when the user has a deactivated email subscription" do
        let(:status) { 410 }

        it "returns a 404" do
          stub_account_manager
          get email_subscription_path(subscription_name: "transition-checker-results"), headers: headers
          expect(response).to have_http_status(:not_found)
        end
      end

      context "when the user does not have an email subscription" do
        let(:status) { 404 }

        it "returns a 404" do
          stub_account_manager
          get email_subscription_path(subscription_name: "transition-checker-results"), headers: headers
          expect(response).to have_http_status(:not_found)
        end
      end

      context "when the tokens are rejected" do
        before { stub_request(:post, "http://openid-provider/token-endpoint").to_return(status: 401) }

        let(:status) { 401 }

        it "returns a 401" do
          stub_account_manager
          get email_subscription_path(subscription_name: "transition-checker-results"), headers: headers
          expect(response).to have_http_status(:unauthorized)
        end
      end

      def stub_account_manager
        stub_get = stub_request(:get, "#{Plek.find('account-manager')}/api/v1/transition-checker/email-subscription")
          .to_return(status: status, body: { topic_slug: slug, subscription_id: subscription_id }.to_json)
        stub_delete = stub_request(:delete, "#{Plek.find('account-manager')}/api/v1/transition-checker/email-subscription")
          .to_return(status: 204)

        { get: stub_get, delete: stub_delete }
      end
    end
  end

  describe "PUT /api/email-subscriptions/:subscription_name" do
    let(:params) { { topic_slug: "slug" } }
    let(:email) { "email@example.com" }
    let(:email_verified) { false }

    it "creates a new subscription record if one doesn't already exist" do
      stub_local_attributes

      expect { put email_subscription_path(subscription_name: "name"), params: params.to_json, headers: headers }.to change(EmailSubscription, :count).by(1)

      expect(response).to be_successful
      expect(JSON.parse(response.body)["email_subscription"]).to eq(EmailSubscription.last.to_hash)
    end

    it "fetches the email & email_verified attributes if they aren't cached locally" do
      stub_oidc_discovery
      stub = stub_userinfo(email: "email@example.com", email_verified: false)

      expect { put email_subscription_path(subscription_name: "name"), params: params.to_json, headers: headers }.to change(EmailSubscription, :count).by(1)

      expect(response).to be_successful
      expect(JSON.parse(response.body)["email_subscription"]).to eq(EmailSubscription.last.to_hash)

      expect(stub).to have_been_made
    end

    context "when the user has verified their email address" do
      let(:email_verified) { true }

      it "calls email-alert-api to create the subscription" do
        expect_activate_email_subscription do
          stub_local_attributes

          expect { put email_subscription_path(subscription_name: "name"), params: params.to_json, headers: headers }.to change(EmailSubscription, :count).by(1)

          expect(response).to be_successful
          expect(JSON.parse(response.body)["email_subscription"]).to eq(EmailSubscription.last.to_hash)
        end
      end
    end

    context "when the subscription already exists" do
      let!(:email_subscription) do
        FactoryBot.create(:email_subscription, oidc_user: session_identifier.user, email_alert_api_subscription_id: "prior-subscription-id")
      end

      before { stub_local_attributes }

      it "calls email-alert-api to deactivate the old subscription" do
        stub_cancel_old = stub_email_alert_api_unsubscribes_a_subscription(email_subscription.email_alert_api_subscription_id)

        put email_subscription_path(subscription_name: email_subscription.name), params: params.to_json, headers: headers

        expect(response).to be_successful
        expect(JSON.parse(response.body)["email_subscription"]).to eq(EmailSubscription.last.to_hash)
        expect(stub_cancel_old).to have_been_made
      end

      context "when the user has verified their email address" do
        let(:email_verified) { true }

        it "calls email-alert-api to create the new subscription" do
          expect_activate_email_subscription do
            stub_email_alert_api_unsubscribes_a_subscription(email_subscription.email_alert_api_subscription_id)

            put email_subscription_path(subscription_name: email_subscription.name), params: params.to_json, headers: headers

            expect(response).to be_successful
            expect(JSON.parse(response.body)["email_subscription"]).to eq(EmailSubscription.last.to_hash)
          end
        end
      end
    end

    context "when it's the transition checker subscription" do
      before do
        stub_oidc_discovery

        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(OidcClient).to receive(:tokens!).and_return({ access_token: "access-token", refresh_token: "refresh-token" })
        # rubocop:enable RSpec/AnyInstance

        stub_local_attributes
        stub_email_alert_api_unsubscribes_a_subscription(subscription_id)
      end

      let(:status) { 200 }
      let(:body) { nil }
      let(:slug) { "slug" }
      let(:subscription_id) { "id" }

      it "calls the account manager and migrates the subscription" do
        stubs = stub_account_manager
        put email_subscription_path(subscription_name: "transition-checker-results"), headers: headers, params: { topic_slug: slug }.to_json
        expect(stubs[:get]).to have_been_made
        expect(stubs[:delete]).to have_been_made
      end

      it "returns the subscription details" do
        stub_account_manager
        put email_subscription_path(subscription_name: "transition-checker-results"), headers: headers, params: { topic_slug: slug }.to_json
        expect(response).to be_successful

        response_subscription_details = JSON.parse(response.body)["email_subscription"]
        database_subscription_details = EmailSubscription.where(name: "transition-checker-results").last.to_hash
        expect(response_subscription_details).to eq(database_subscription_details)
      end

      context "when the subscription has already been migrated" do
        before do
          FactoryBot.create(:email_subscription, oidc_user: session_identifier.user, name: "transition-checker-results", topic_slug: "slug")
        end

        it "does not re-migrate it" do
          stubs = stub_account_manager
          put email_subscription_path(subscription_name: "transition-checker-results"), headers: headers, params: { topic_slug: slug }.to_json
          expect(stubs[:get]).not_to have_been_made
          expect(stubs[:delete]).not_to have_been_made
        end
      end

      context "when the tokens are rejected" do
        before { stub_request(:post, "http://openid-provider/token-endpoint").to_return(status: 401) }

        let(:status) { 401 }

        it "returns a 401" do
          stub_account_manager

          put email_subscription_path(subscription_name: "transition-checker-results"), headers: headers, params: { topic_slug: slug }.to_json
          expect(response).to have_http_status(:unauthorized)
        end
      end

      def stub_account_manager
        stub_get = stub_request(:get, "#{Plek.find('account-manager')}/api/v1/transition-checker/email-subscription")
          .to_return(status: status, body: { topic_slug: slug, subscription_id: subscription_id }.to_json)
        stub_delete = stub_request(:delete, "#{Plek.find('account-manager')}/api/v1/transition-checker/email-subscription")
          .to_return(status: 204)

        { get: stub_get, delete: stub_delete }
      end
    end

    def stub_local_attributes
      LocalAttribute.create!(oidc_user: session_identifier.user, name: "email", value: email)
      LocalAttribute.create!(oidc_user: session_identifier.user, name: "email_verified", value: email_verified)
    end

    def expect_activate_email_subscription
      stub_fetch_topic = stub_email_alert_api_has_subscriber_list_by_slug(
        slug: params[:topic_slug],
        returned_attributes: { id: "list-id" },
      )

      stub_create_new = stub_email_alert_api_creates_a_subscription(
        subscriber_list_id: "list-id",
        address: "email@example.com",
        frequency: "daily",
        returned_subscription_id: "new-subscription-id",
        skip_confirmation_email: true,
      )

      yield

      expect(stub_fetch_topic).to have_been_made
      expect(stub_create_new).to have_been_made
    end
  end

  describe "DELETE /api/email-subscriptions/:subscription_name" do
    it "returns a 404" do
      delete email_subscription_path(subscription_name: "foo"), headers: headers
      expect(response).to have_http_status(:not_found)
    end

    context "when the subscription exists" do
      let!(:email_subscription) do
        FactoryBot.create(:email_subscription, oidc_user: session_identifier.user, email_alert_api_subscription_id: "prior-subscription-id")
      end

      it "deletes it, calls email-alert-api to cancel the old subscription, and returns a 204" do
        stub_cancel_old = stub_email_alert_api_unsubscribes_a_subscription(email_subscription.email_alert_api_subscription_id)

        expect { delete email_subscription_path(subscription_name: email_subscription.name), headers: headers }.to change(EmailSubscription, :count).by(-1)

        expect(response).to have_http_status(:no_content)
        expect(stub_cancel_old).to have_been_made
      end
    end

    context "when it's the transition checker subscription" do
      before do
        stub_oidc_discovery

        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(OidcClient).to receive(:tokens!).and_return({ access_token: "access-token", refresh_token: "refresh-token" })
        # rubocop:enable RSpec/AnyInstance
      end

      let(:status) { 200 }
      let(:body) { nil }
      let(:slug) { "slug" }
      let(:subscription_id) { "id" }

      it "calls the account manager and migrates the subscription" do
        stubs = stub_account_manager
        stub_email_alert_api_unsubscribes_a_subscription(subscription_id)
        delete email_subscription_path(subscription_name: "transition-checker-results"), headers: headers, params: { topic_slug: slug }.to_json
        expect(stubs[:get]).to have_been_made
        expect(stubs[:delete]).to have_been_made
      end

      context "when the subscription has already been migrated" do
        before do
          FactoryBot.create(:email_subscription, oidc_user: session_identifier.user, name: "transition-checker-results", topic_slug: "slug")
        end

        it "does not re-migrate it" do
          stubs = stub_account_manager
          stub_email_alert_api_unsubscribes_a_subscription(subscription_id)
          delete email_subscription_path(subscription_name: "transition-checker-results"), headers: headers, params: { topic_slug: slug }.to_json
          expect(stubs[:get]).not_to have_been_made
          expect(stubs[:delete]).not_to have_been_made
        end
      end

      context "when the tokens are rejected" do
        before { stub_request(:post, "http://openid-provider/token-endpoint").to_return(status: 401) }

        let(:status) { 401 }

        it "returns a 401" do
          stub_account_manager

          delete email_subscription_path(subscription_name: "transition-checker-results"), headers: headers, params: { topic_slug: slug }.to_json
          expect(response).to have_http_status(:unauthorized)
        end
      end

      def stub_account_manager
        stub_get = stub_request(:get, "#{Plek.find('account-manager')}/api/v1/transition-checker/email-subscription")
          .to_return(status: status, body: { topic_slug: slug, subscription_id: subscription_id }.to_json)
        stub_delete = stub_request(:delete, "#{Plek.find('account-manager')}/api/v1/transition-checker/email-subscription")
          .to_return(status: 204)

        { get: stub_get, delete: stub_delete }
      end
    end
  end
end
