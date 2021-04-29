RSpec.describe AttributesController do
  before do
    stub_oidc_discovery

    fixture_file = YAML.safe_load(File.read(Rails.root.join("spec/fixtures/user_attributes.yml"))).with_indifferent_access
    allow(UserAttributes).to receive(:load_config_file).and_return(fixture_file)
  end

  let(:session_identifier) { placeholder_govuk_account_session }
  let(:headers) { { "Content-Type" => "application/json", "GOVUK-Account-Session" => session_identifier } }

  # names must be defined in spec/fixtures/user_attributes.yml
  let(:attribute_name1) { "test_attribute_1" }
  let(:attribute_name2) { "test_attribute_2" }
  let(:local_attribute_name) { "test_local_attribute" }
  let(:attribute_value1) { { "some" => "complex", "value" => 42 } }
  let(:attribute_value2) { [1, 2, 3, 4, 5] }
  let(:local_attribute_value) { [1, 2, { "buckle" => %w[my shoe] }] }

  describe "GET" do
    before do
      stub_request(:get, "http://openid-provider/v1/attributes/#{attribute_name1}")
        .to_return(status: status, body: { claim_value: attribute_value1 }.compact.to_json)
    end

    let(:params) { { attributes: [attribute_name1] } }
    let(:status) { 200 }

    it "returns the attribute" do
      get attributes_path, headers: headers, params: params
      expect(response).to be_successful
      expect(JSON.parse(response.body)["values"]).to eq({ attribute_name1 => attribute_value1 })
    end

    context "when the attribute is not found" do
      let(:status) { 404 }

      it "returns no value" do
        get attributes_path, headers: headers, params: params
        expect(response).to be_successful
        expect(JSON.parse(response.body)["values"]).to eq({})
      end
    end

    context "when the tokens are rejected" do
      before { stub_request(:post, "http://openid-provider/token-endpoint").to_return(status: 401) }

      let(:status) { 401 }

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

    context "when the user doesn't have a high enough level of authentication" do
      let(:session_identifier) { placeholder_govuk_account_session(level_of_authentication: "level-1") }

      it "returns the attribute" do
        get attributes_path, headers: headers, params: params
        expect(response).to be_successful
        expect(JSON.parse(response.body)["values"]).to eq({ attribute_name1 => attribute_value1 })
      end

      context "when the feature flag is toggled on" do
        before { allow(Rails.configuration).to receive(:feature_flag_enforce_levels_of_authentication).and_return(true) }

        it "returns a 403 and the required level" do
          get attributes_path, headers: headers, params: params
          expect(response).to have_http_status(:forbidden)

          error = JSON.parse(response.body)
          expect(error["type"]).to eq(I18n.t("errors.level_of_authentication_too_low.type"))
          expect(error["attributes"]).to eq([attribute_name1])
          expect(error["needed_level_of_authentication"]).to eq("level0")
        end
      end
    end

    context "when multiple attributes are requested" do
      before do
        stub_request(:get, "http://openid-provider/v1/attributes/#{attribute_name2}")
          .to_return(status: 200, body: { claim_value: attribute_value2 }.compact.to_json)

        LocalAttribute.create!(
          oidc_user: OidcUser.find_or_create_by(sub: "user-id"),
          name: local_attribute_name,
          value: local_attribute_value,
        )
      end

      let(:params) { { attributes: [attribute_name1, attribute_name2, local_attribute_name] } }

      it "returns all the attributes" do
        get attributes_path, headers: headers, params: params
        expect(response).to be_successful
        expect(JSON.parse(response.body)["values"]).to eq(
          {
            attribute_name1 => attribute_value1,
            attribute_name2 => attribute_value2,
            local_attribute_name => local_attribute_value,
          },
        )
      end

      context "when one of the attributes is not found" do
        let(:status) { 404 }

        it "returns only the present attribute" do
          get attributes_path, headers: headers, params: params
          expect(response).to be_successful
          expect(JSON.parse(response.body)["values"]).to eq({ attribute_name2 => attribute_value2, local_attribute_name => local_attribute_value })
        end
      end

      context "when some of the attributes are undefined" do
        let(:bad_attributes) { %w[bad1 bad2] }
        let(:params) { { attributes: [attribute_name1, attribute_name2] + bad_attributes } }

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
    let(:attributes) { { attribute_name1 => attribute_value1, attribute_name2 => attribute_value2 } }
    let(:params) { { attributes: attributes } }

    it "calls the attribute service" do
      stub = stub_request(:post, "http://openid-provider/v1/attributes")
        .with(body: { attributes: attributes.transform_values(&:to_json) })
        .to_return(status: 200)

      patch attributes_path, headers: headers, params: params.to_json
      expect(response).to be_successful
      expect(stub).to have_been_made
    end

    context "when there is a local attribute" do
      let(:remote_attributes) { { attribute_name1 => attribute_value1, attribute_name2 => attribute_value2 } }
      let(:attributes) { remote_attributes.merge(local_attribute_name => local_attribute_value) }

      before do
        stub_request(:post, "http://openid-provider/v1/attributes")
          .with(body: { attributes: remote_attributes.transform_values(&:to_json) })
          .to_return(status: 200)
      end

      it "doesn't send the local attribute to the attribute service" do
        patch attributes_path, headers: headers, params: params.to_json
        expect(response).to be_successful
      end

      it "correctly round-trips the local attribute" do
        old_value = "hello world"

        LocalAttribute.create!(
          oidc_user: OidcUser.find_or_create_by(sub: "user-id"),
          name: local_attribute_name,
          value: old_value,
        )

        get attributes_path, headers: headers, params: { attributes: [local_attribute_name] }
        expect(JSON.parse(response.body)["values"]).to eq({ local_attribute_name => old_value })

        patch attributes_path, headers: headers, params: params.to_json

        get attributes_path, headers: headers, params: { attributes: [local_attribute_name] }
        expect(JSON.parse(response.body)["values"]).to eq({ local_attribute_name => local_attribute_value })
      end
    end

    context "when there are no attributes" do
      let(:attributes) { {} }

      it "doesn't call the attribute service" do
        stub = stub_request(:post, "http://openid-provider/v1/attributes")
          .with(body: { attributes: {} })
          .to_return(status: 200)

        patch attributes_path, headers: headers, params: params.to_json
        expect(response).to be_successful
        expect(stub).not_to have_been_made
      end
    end

    context "when the tokens are rejected" do
      before do
        stub_request(:post, "http://openid-provider/token-endpoint").to_return(status: 401)

        stub_request(:post, "http://openid-provider/v1/attributes")
          .with(body: { attributes: attributes.transform_values(&:to_json) })
          .to_return(status: 401)
      end

      it "returns a 401" do
        patch attributes_path, headers: headers, params: params.to_json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when no govuk-account-session is provided" do
      it "returns a 401" do
        patch attributes_path, headers: { "Content-Type" => "application/json" }, params: params.to_json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when the user doesn't have a high enough level of authentication" do
      let(:session_identifier) { placeholder_govuk_account_session(level_of_authentication: "level-1") }

      it "calls the attribute service" do
        stub = stub_request(:post, "http://openid-provider/v1/attributes")
          .with(body: { attributes: attributes.transform_values(&:to_json) })
          .to_return(status: 200)

        patch attributes_path, headers: headers, params: params.to_json
        expect(response).to be_successful
        expect(stub).to have_been_made
      end

      context "when the feature flag is toggled on" do
        before { allow(Rails.configuration).to receive(:feature_flag_enforce_levels_of_authentication).and_return(true) }

        it "returns a 403 and the required level" do
          patch attributes_path, headers: headers, params: params.to_json
          expect(response).to have_http_status(:forbidden)

          error = JSON.parse(response.body)
          expect(error["type"]).to eq(I18n.t("errors.level_of_authentication_too_low.type"))
          expect(error["attributes"]).to eq([attribute_name1, attribute_name2])
          expect(error["needed_level_of_authentication"]).to eq("level0")
        end
      end
    end
  end
end
