RSpec.describe "OIDC Users endpoint" do
  let(:headers) { { "Content-Type" => "application/json" } }
  let(:params) { { email: email, email_verified: email_verified }.compact.to_json }
  let(:email) { "email@example.com" }
  let(:email_verified) { true }
  let(:subject_identifier) { "subject-identifier" }

  describe "PUT" do
    it "creates the user if they do not exist" do
      expect { put oidc_user_path(subject_identifier: subject_identifier), params: params, headers: headers }.to change(OidcUser, :count)
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

        expect(user.get_local_attributes(%i[email email_verified])).to eq({ "email" => email, "email_verified" => email_verified })
      end
    end
  end
end
