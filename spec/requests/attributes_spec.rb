RSpec.describe "Attributes" do
  before do
    stub_oidc_discovery
    stub_userinfo
  end

  let(:session_identifier) { account_session.serialise }
  let(:account_session) { placeholder_govuk_account_session_object(mfa:, digital_identity_session:) }
  let(:mfa) { true }
  let(:digital_identity_session) { true }
  let(:headers) { { "Content-Type" => "application/json", "GOVUK-Account-Session" => session_identifier } }

  let(:cached_attribute_name) { "email" }
  let(:cached_attribute_value) { "email@example.com" }

  let(:local_attribute_name) { "local_attribute" }
  let(:local_attribute_value) { true }

  let(:protected_attribute_name) { "test_mfa_attribute" }

  let(:unwritable_attribute_name) { cached_attribute_name }

  describe "GET" do
    before do
      account_session.set_attributes(cached_attribute_name => cached_attribute_value)
    end

    let(:attribute_name) { cached_attribute_name }
    let(:attribute_value) { cached_attribute_value }
    let(:params) { { attributes: [attribute_name] } }

    it "returns the attribute" do
      get attributes_path, headers: headers, params: params
      expect(response).to be_successful
      expect(JSON.parse(response.body)["values"]).to eq({ attribute_name => attribute_value })
    end

    context "when a cached attribute is not found" do
      let(:cached_attribute_value) { nil }

      it "returns a 401" do
        get attributes_path, headers: headers, params: params
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when no govuk-account-session is provided" do
      it "returns a 401" do
        get attributes_path, params: params
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when an invalid govuk-account-session is provided" do
      it "returns a 401" do
        get attributes_path, headers: { "GOVUK-Account-Session" => "not-a-base64-string" }, params: params
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when the user tries to get a protected attribute without having done MFA" do
      let(:mfa) { false }
      let(:attribute_name) { protected_attribute_name }

      it "returns a 403" do
        get attributes_path, headers: headers, params: params
        expect(response).to have_http_status(:forbidden)

        error = JSON.parse(response.body)
        expect(error["type"]).to eq(I18n.t("errors.mfa_required.type"))
        expect(error["attributes"]).to eq([attribute_name])
      end
    end

    context "when multiple attributes are requested" do
      before do
        account_session.user.update!(local_attribute_name => local_attribute_value)
      end

      let(:params) { { attributes: [cached_attribute_name, local_attribute_name] } }

      it "returns all the attributes" do
        get attributes_path, headers: headers, params: params
        expect(response).to be_successful
        expect(JSON.parse(response.body)["values"]).to eq(
          {
            cached_attribute_name => cached_attribute_value,
            local_attribute_name => local_attribute_value,
          },
        )
      end

      context "when one of the attributes is not found" do
        let(:local_attribute_value) { nil }

        it "returns only the present attribute" do
          get attributes_path, headers: headers, params: params
          expect(response).to be_successful
          expect(JSON.parse(response.body)["values"]).to eq({ cached_attribute_name => cached_attribute_value })
        end
      end

      context "when some of the attributes are undefined" do
        let(:bad_attributes) { %w[bad1 bad2] }
        let(:params) { { attributes: [cached_attribute_name] + bad_attributes } }

        it "lists the undefined ones" do
          get attributes_path, headers: headers, params: params
          expect(response).to have_http_status(:unprocessable_entity)

          error = JSON.parse(response.body)
          expect(error["type"]).to eq(I18n.t("errors.unknown_attribute_names.type"))
          expect(error["attributes"]).to eq(bad_attributes)
        end
      end
    end
  end

  describe "PATCH" do
    let(:attributes) { { local_attribute_name => local_attribute_value } }
    let(:params) { { attributes: } }

    it "updates the database" do
      patch attributes_path, headers: headers, params: params.to_json
      expect(account_session.user[local_attribute_name]).to eq(local_attribute_value)
      expect(response).to be_successful
    end

    it "correctly round-trips local attributes" do
      old_value = false

      account_session.user.update!(local_attribute_name => old_value)

      get attributes_path, headers: headers, params: { attributes: [local_attribute_name] }
      expect(JSON.parse(response.body)["values"]).to eq({ local_attribute_name => old_value })

      patch attributes_path, headers: headers, params: params.to_json

      get attributes_path, headers: headers, params: { attributes: [local_attribute_name] }
      expect(JSON.parse(response.body)["values"]).to eq({ local_attribute_name => local_attribute_value })
    end

    context "when no govuk-account-session is provided" do
      it "returns a 401" do
        patch attributes_path, headers: { "Content-Type" => "application/json" }, params: params.to_json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when the attribute is unwritable" do
      let(:attributes) { { unwritable_attribute_name => "foo" } }

      it "returns a 403" do
        patch attributes_path, headers: headers, params: params.to_json
        expect(response).to have_http_status(:forbidden)

        error = JSON.parse(response.body)
        expect(error["type"]).to eq(I18n.t("errors.unwritable_attributes.type"))
        expect(error["attributes"]).to eq([unwritable_attribute_name])
      end
    end

    context "when the user tries to set a protected attribute without having done MFA" do
      let(:mfa) { false }
      let(:attributes) { { protected_attribute_name => "foo" } }

      it "returns a 403" do
        patch attributes_path, headers: headers, params: params.to_json
        expect(response).to have_http_status(:forbidden)

        error = JSON.parse(response.body)
        expect(error["type"]).to eq(I18n.t("errors.mfa_required.type"))
        expect(error["attributes"]).to eq([protected_attribute_name])
      end
    end
  end
end
