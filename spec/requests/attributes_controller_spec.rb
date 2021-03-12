RSpec.describe AttributesController do
  before { stub_oidc_discovery }

  let(:headers) { { "GOVUK-Account-Session" => placeholder_govuk_account_session } }

  let(:attribute_name1) { "name" }
  let(:attribute_value1) { { "some" => "complex", "value" => 42 } }

  let(:attribute_name2) { "name2" }
  let(:attribute_value2) { [1, 2, 3, 4, 5] }

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

    context "when multiple attributes are requested" do
      before do
        stub_request(:get, "http://openid-provider/v1/attributes/#{attribute_name2}")
          .to_return(status: 200, body: { claim_value: attribute_value2 }.compact.to_json)
      end

      let(:params) { { attributes: [attribute_name1, attribute_name2] } }

      it "returns all the attributes" do
        get attributes_path, headers: headers, params: params
        expect(response).to be_successful
        expect(JSON.parse(response.body)["values"]).to eq({ attribute_name1 => attribute_value1, attribute_name2 => attribute_value2 })
      end

      context "when one of the attributes is not found" do
        let(:status) { 404 }

        it "returns only the present attribute" do
          get attributes_path, headers: headers, params: params
          expect(response).to be_successful
          expect(JSON.parse(response.body)["values"]).to eq({ attribute_name2 => attribute_value2 })
        end
      end
    end
  end

  describe "PATCH" do
    let(:attributes) { { attribute_name1 => attribute_value1.to_json, attribute_name2 => attribute_value2.to_json } }
    let(:params) { { attributes: attributes } }

    it "calls the attribute service" do
      stub = stub_request(:post, "http://openid-provider/v1/attributes")
        .with(body: { attributes: attributes })
        .to_return(status: 200)

      patch attributes_path, headers: headers, params: params
      expect(response).to be_successful
      expect(stub).to have_been_made
    end

    context "when the tokens are rejected" do
      before do
        stub_request(:post, "http://openid-provider/token-endpoint").to_return(status: 401)

        stub_request(:post, "http://openid-provider/v1/attributes")
          .with(body: { attributes: attributes })
          .to_return(status: 401)
      end

      it "returns a 401" do
        patch attributes_path, headers: headers, params: params
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when no govuk-account-session is provided" do
      it "returns a 401" do
        patch attributes_path, params: params
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
