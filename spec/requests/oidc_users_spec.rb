require "gds_api/test_helpers/email_alert_api"

RSpec.describe "OIDC Users endpoint" do
  include GdsApi::TestHelpers::EmailAlertApi

  let(:subject_identifier) { "subject-identifier" }
  let(:legacy_sub) { nil }

  describe "PUT" do
    let(:headers) { { "Content-Type" => "application/json" } }
    let(:params) do
      {
        email:,
        email_verified:,
        legacy_sub:,
      }.compact.to_json
    end
    let(:email) { "email@example.com" }
    let(:email_verified) { true }

    before do
      stub_request(:get, %r{\A#{GdsApi::TestHelpers::EmailAlertApi::EMAIL_ALERT_API_ENDPOINT}/subscribers/govuk-account/\d+\z}).to_return(status: 404)
    end

    it "creates the user if they do not exist" do
      expect { put oidc_user_path(subject_identifier:), params:, headers: }.to change(OidcUser, :count).by(1)
      expect(response).to be_successful
    end

    it "returns the subject identifier" do
      put(oidc_user_path(subject_identifier:), params:, headers:)
      expect(JSON.parse(response.body)["sub"]).to eq(subject_identifier)
    end

    it "returns the new attribute values" do
      put(oidc_user_path(subject_identifier:), params:, headers:)
      expect(JSON.parse(response.body)["email"]).to eq(email)
      expect(JSON.parse(response.body)["email_verified"]).to eq(email_verified)
    end

    context "when the user already exists" do
      let!(:user) { FactoryBot.create(:oidc_user, sub: subject_identifier, legacy_sub:) }

      it "does not create a new user" do
        expect { put oidc_user_path(subject_identifier:), params:, headers: }.not_to change(OidcUser, :count)
        expect(response).to be_successful
      end

      it "updates the attribute values" do
        user.update!(email: "old-email@example.com", email_verified: false)

        put(oidc_user_path(subject_identifier:), params:, headers:)
        expect(JSON.parse(response.body)["email"]).to eq(email)
        expect(JSON.parse(response.body)["email_verified"]).to eq(email_verified)

        user.reload
        expect(user.email).to eq(email)
        expect(user.email_verified).to eq(email_verified)
      end

      it "doesn't update nil attributes" do
        put(oidc_user_path(subject_identifier:), params:, headers:)
        put(oidc_user_path(subject_identifier:), params: { email: "new-email@example.com", email_verified: nil }.to_json, headers:)
        expect(JSON.parse(response.body)["email"]).to eq("new-email@example.com")
        expect(JSON.parse(response.body)["email_verified"]).to eq(email_verified)

        user.reload
        expect(user.email).to eq("new-email@example.com")
        expect(user.email_verified).to eq(email_verified)
      end

      context "when a different user tried to use the same email address" do
        let!(:other_user) { FactoryBot.create(:oidc_user) }
        let(:email) { user.email }

        it "creates a sensitive exception" do
          expect(GovukError).to receive(:notify)
          expect { put oidc_user_path(subject_identifier: other_user.sub), params:, headers: }.to change(SensitiveException, :count).by(1)
          expect(response).to have_http_status(:internal_server_error)
        end
      end

      context "when the user is pre-migration" do
        let(:legacy_sub) { "legacy-subject-identifier" }
        let(:subject_identifier) { "pre-migration-subject-identifier" }

        it "updates and migrates the user by legacy_sub" do
          user.update!(email: "old-email@example.com", email_verified: false)

          put(oidc_user_path(subject_identifier: "post-migration-subject-identifier"), params:, headers:)
          expect(JSON.parse(response.body)["sub"]).to eq("post-migration-subject-identifier")
          expect(JSON.parse(response.body)["email"]).to eq(email)
          expect(JSON.parse(response.body)["email_verified"]).to eq(email_verified)

          user.reload
          expect(user.sub).to eq("post-migration-subject-identifier")
          expect(user.email).to eq(email)
          expect(user.email_verified).to eq(email_verified)
        end
      end

      context "when the user has linked their notifications account" do
        before do
          stub_email_alert_api_find_subscriber_by_govuk_account(user.id, subscriber_id, "old-address@example.com")
        end

        let(:subscriber_id) { "subscriber-id" }

        it "updates the subscriber" do
          stub = stub_email_alert_api_has_updated_subscriber(subscriber_id, email, govuk_account_id: user.id)
          put(oidc_user_path(subject_identifier:), params:, headers:)
          expect(response).to be_successful
          expect(stub).to have_been_made
        end
      end
    end
  end

  describe "DELETE" do
    it "does not change the count of users and returns not found" do
      without_detailed_exceptions do
        expect { delete oidc_user_path(subject_identifier:) }.not_to change(OidcUser, :count)
      end
      expect(response).to be_not_found
    end

    context "when the user exists" do
      let!(:user) { FactoryBot.create(:oidc_user, sub: subject_identifier, legacy_sub:) }

      before do
        stub_request(:get, "#{GdsApi::TestHelpers::EmailAlertApi::EMAIL_ALERT_API_ENDPOINT}/subscribers/govuk-account/#{user.id}").to_return(status: 404)
      end

      it "deletes the user" do
        expect { delete oidc_user_path(subject_identifier:) }.to change(OidcUser, :count).by(-1)
        expect(response).to be_no_content
      end

      context "when the user has linked their notifications account" do
        before do
          stub_email_alert_api_find_subscriber_by_govuk_account(user.id, subscriber_id, user.email)
        end

        let(:subscriber_id) { "subscriber-id" }

        it "ends their subscriptions" do
          stub = stub_email_alert_api_unsubscribes_a_subscriber(subscriber_id)
          delete oidc_user_path(subject_identifier:)
          expect(stub).to have_been_made
        end
      end

      context "when the user is pre-migration" do
        let(:legacy_sub) { "legacy-subject-identifier" }
        let(:subject_identifier) { "pre-migration-subject-identifier" }

        it "deletes the user by legacy_sub" do
          expect { delete oidc_user_path(subject_identifier: "post-migration-subject-identifier"), params: { legacy_sub: } }.to change(OidcUser, :count).by(-1)
          expect(response).to be_no_content
        end
      end
    end
  end
end
