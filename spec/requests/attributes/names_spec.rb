RSpec.describe "Attribute names" do
  before do
    stub_oidc_discovery
    stub_userinfo

    normal_file = YAML.safe_load(File.read(Rails.root.join("config/user_attributes.yml"))).with_indifferent_access
    fixture_file = YAML.safe_load(File.read(Rails.root.join("spec/fixtures/user_attributes.yml"))).with_indifferent_access
    allow(UserAttributes).to receive(:load_config_file).and_return(normal_file.merge(fixture_file))
  end

  let(:session_identifier) { placeholder_govuk_account_session }
  let(:headers) { { "Content-Type" => "application/json", "GOVUK-Account-Session" => session_identifier } }

  # names must be defined in spec/fixtures/user_attributes.yml
  let(:attribute_name1) { "test_attribute_1" }
  let(:attribute_name2) { "test_attribute_2" }
  let(:local_attribute_name) { "transition_checker_state" }
  let(:unknown_attribute_name1) { "this_does_not_exist1" }
  let(:unknown_attribute_name2) { "this_does_not_exist2" }

  let(:attribute_value1) { "some_value1" }
  let(:attribute_value2) { "some_value2" }
  let(:local_attribute_value) { [1, 2, { "buckle" => %w[my shoe] }] }

  let(:response_body) { JSON.parse(response.body) }

  describe "GET #show" do
    context "when a single attribute is requested" do
      before do
        stub_userinfo(attribute_name1 => attribute_value1)
        get attributes_names_path, headers: headers, params: params
      end

      context "when the attribute is known" do
        let(:params) { { attributes: [attribute_name1] } }

        context "when the attribute has a value" do
          it "returns the attribute name" do
            expect(response).to be_successful
            expect(response_body["values"]).to eq([attribute_name1])
          end
        end

        context "when the attribute has no value" do
          let(:attribute_value1) { nil }

          it "returns an empty array" do
            expect(response).to be_successful
            expect(response_body["values"]).to eq([])
          end
        end
      end

      context "when the attribute is unknown" do
        let(:params) { { attributes: [unknown_attribute_name1] } }

        it "returns the appropriate error" do
          expect(response).to have_http_status(:unprocessable_entity)
          expect(response_body["type"]).to eq(I18n.t("errors.unknown_attribute_names.type"))
          expect(response_body["attributes"]).to eq([unknown_attribute_name1])
        end
      end
    end

    context "when multiple attributes are requested" do
      before do
        stub_userinfo(
          attribute_name1 => attribute_value1,
          attribute_name2 => attribute_value2,
        )

        LocalAttribute.create!(
          oidc_user: OidcUser.find_or_create_by(sub: "user-id"),
          name: local_attribute_name,
          value: local_attribute_value,
        )

        get attributes_names_path, headers: headers, params: params
      end

      context "when all attributes are known" do
        let(:params) { { attributes: [attribute_name1, attribute_name2, local_attribute_name] } }

        context "when all attributes have a value" do
          it "returns all attributes names" do
            expect(response).to be_successful
            expect(response_body["values"].sort).to eq([attribute_name1, attribute_name2, local_attribute_name].sort)
          end
        end

        context "when all attributes have no value" do
          let(:params) { { attributes: [attribute_name1, attribute_name2] } }
          let(:attribute_value1) { nil }
          let(:attribute_value2) { nil }

          it "returns an empty array" do
            expect(response).to be_successful
            expect(response_body["values"]).to eq([])
          end
        end

        context "when some attributes have no value" do
          let(:attribute_value2) { nil }

          it "returns only names of attributes with a value" do
            expect(response).to be_successful
            expect(response_body["values"].sort).to eq([attribute_name1, local_attribute_name].sort)
          end
        end
      end

      context "when all attributes are unknown" do
        let(:params) { { attributes: [unknown_attribute_name1, unknown_attribute_name2] } }

        it "returns the appropriate error" do
          expect(response).to have_http_status(:unprocessable_entity)
          expect(response_body["type"]).to eq(I18n.t("errors.unknown_attribute_names.type"))
          expect(response_body["attributes"]).to eq([unknown_attribute_name1, unknown_attribute_name2])
        end
      end

      context "when some attributes are unknown" do
        let(:params) { { attributes: [attribute_name1, unknown_attribute_name1] } }

        it "returns the appropriate error" do
          expect(response).to have_http_status(:unprocessable_entity)
          expect(response_body["type"]).to eq(I18n.t("errors.unknown_attribute_names.type"))
          expect(response_body["attributes"]).to eq([unknown_attribute_name1])
        end
      end
    end
  end
end
