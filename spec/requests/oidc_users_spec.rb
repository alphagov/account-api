require "gds_api/test_helpers/email_alert_api"

RSpec.describe "OIDC Users endpoint" do
  include GdsApi::TestHelpers::EmailAlertApi

  let(:headers) { { "Content-Type" => "application/json" } }
  let(:params) { { email: email, email_verified: email_verified, has_unconfirmed_email: has_unconfirmed_email }.compact.to_json }
  let(:email) { "email@example.com" }
  let(:email_verified) { true }
  let(:has_unconfirmed_email) { false }
  let(:subject_identifier) { "subject-identifier" }

  describe "PUT" do
    it "creates the user if they do not exist" do
      expect { put oidc_user_path(subject_identifier: subject_identifier), params: params, headers: headers }.to change(OidcUser, :count).by(1)
      expect(response).to be_successful
    end

    it "returns the subject identifier" do
      put oidc_user_path(subject_identifier: subject_identifier), params: params, headers: headers
      expect(JSON.parse(response.body)["sub"]).to eq(subject_identifier)
    end

    it "returns the new attribute values" do
      put oidc_user_path(subject_identifier: subject_identifier), params: params, headers: headers
      expect(JSON.parse(response.body)["email"]).to eq(email)
      expect(JSON.parse(response.body)["email_verified"]).to eq(email_verified)
      expect(JSON.parse(response.body)["has_unconfirmed_email"]).to eq(has_unconfirmed_email)
    end

    context "when the user already exists" do
      let!(:user) { OidcUser.create!(sub: subject_identifier) }

      it "does not create a new user" do
        expect { put oidc_user_path(subject_identifier: subject_identifier), params: params, headers: headers }.not_to change(OidcUser, :count)
        expect(response).to be_successful
      end

      it "updates the attribute values" do
        user.set_local_attributes(email: "old-email@example.com", email_verified: false)

        put oidc_user_path(subject_identifier: subject_identifier), params: params, headers: headers

        expect(user.get_local_attributes(%i[email email_verified has_unconfirmed_email])).to eq({ "email" => email, "email_verified" => email_verified, "has_unconfirmed_email" => has_unconfirmed_email })
      end

      context "when the user has email subscriptions" do
        before { EmailSubscription.create!(oidc_user: user, name: "name", topic_slug: "slug", email_alert_api_subscription_id: "prior-subscription-id") }

        it "reactivates them" do
          stub_cancel_old = stub_email_alert_api_unsubscribes_a_subscription("prior-subscription-id")
          stub_fetch_topic = stub_email_alert_api_has_subscriber_list_by_slug(slug: "slug", returned_attributes: { id: "list-id" })
          stub_create_new = stub_email_alert_api_creates_a_subscription(
            subscriber_list_id: "list-id",
            address: email,
            frequency: "daily",
            returned_subscription_id: "new-subscription-id",
            skip_confirmation_email: true,
          )

          put oidc_user_path(subject_identifier: subject_identifier), params: params, headers: headers

          expect(stub_cancel_old).to have_been_made
          expect(stub_fetch_topic).to have_been_made
          expect(stub_create_new).to have_been_made
        end
      end
    end
  end
end
