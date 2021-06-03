require "webmock"
require "pact/provider/rspec"
require "gds_api/test_helpers/content_store"

Dir["./spec/support/**/*.rb"].sort.each { |f| require f }

def oidc_user
  OidcUser.find_or_create_by(sub: "user-id")
end

def url_encode(str)
  ERB::Util.url_encode(str)
end

Pact.configure do |config|
  config.reports_dir = "spec/reports/pacts"
  config.include GdsApi::TestHelpers::ContentStore
  config.include GovukAccountSessionHelper
  config.include OidcClientHelper
  config.include WebMock::API
  config.include WebMock::Matchers
end

Pact.service_provider "Account API" do
  honours_pact_with "GDS API Adapters" do
    if ENV["PACT_URI"]
      pact_uri ENV["PACT_URI"]
    else
      base_url = "https://pact-broker.cloudapps.digital"
      path = "pacts/provider/#{url_encode(name)}/consumer/#{url_encode(consumer_name)}"
      version_modifier = "versions/#{url_encode(ENV.fetch('PACT_CONSUMER_VERSION', 'branch-master'))}"

      pact_uri("#{base_url}/#{path}/#{version_modifier}")
    end
  end
end

Pact.provider_states_for "GDS API Adapters" do
  set_up do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.allow_remote_database_url = true
    DatabaseCleaner.start

    WebMock.enable!
    WebMock.reset!

    stub_oidc_discovery
    stub_token_response

    account_session = placeholder_govuk_account_session_object(
      user_id: oidc_user.sub,
      level_of_authentication: "level1",
    )
    allow(AccountSession).to receive(:deserialise).and_return(account_session)

    normal_file = YAML.safe_load(File.read(Rails.root.join("config/user_attributes.yml"))).with_indifferent_access
    fixture_file = YAML.safe_load(File.read(Rails.root.join("spec/fixtures/user_attributes.yml"))).with_indifferent_access
    allow(UserAttributes).to receive(:load_config_file).and_return(normal_file.merge(fixture_file))

    stub_request(:post, "#{Plek.find('account-manager')}/api/v1/jwt").to_return(status: 200, body: { id: "jwt-id" }.to_json)

    stub_content_store_has_item(
      "/guidance/some-govuk-guidance",
      content_item_for_base_path("/guidance/some-govuk-guidance").merge("content_id" => SecureRandom.uuid),
    )
  end

  tear_down do
    WebMock.disable!
    DatabaseCleaner.clean
  end

  provider_state "there is a valid OAuth response" do
    set_up do
      auth_request = AuthRequest.generate!
      allow(AuthRequest).to receive(:from_oauth_state).and_return(auth_request)

      stub_request(:get, "#{Plek.find('account-manager')}/api/v1/ephemeral-state").to_return(status: 200, body: { _ga: "ga-client-id", level_of_authentication: "level0" }.to_json)
    end
  end

  provider_state "there is a valid OAuth response, with the redirect path '/some-arbitrary-path'" do
    set_up do
      auth_request = AuthRequest.generate!(redirect_path: "/some-arbitrary-path")
      allow(AuthRequest).to receive(:from_oauth_state).and_return(auth_request)

      stub_request(:get, "#{Plek.find('account-manager')}/api/v1/ephemeral-state").to_return(status: 200, body: { _ga: "ga-client-id", level_of_authentication: "level0" }.to_json)
    end
  end

  provider_state "there is a valid user session" do
    set_up do
      stub_request(:get, "#{Plek.find('account-manager')}/api/v1/transition-checker/email-subscription").to_return(status: 404)
      stub_request(:post, "#{Plek.find('account-manager')}/api/v1/transition-checker/email-subscription").to_return(status: 200)
      stub_request(:get, "http://openid-provider/v1/attributes/email").to_return(status: 200, body: { claim_value: "user@example.com" }.to_json)
      stub_request(:get, "http://openid-provider/v1/attributes/email_verified").to_return(status: 200, body: { claim_value: true }.to_json)
      stub_request(:get, "http://openid-provider/v1/attributes/transition_checker_state").to_return(status: 404)
      stub_request(:get, "http://openid-provider/v1/attributes/foo").to_return(status: 404)
      stub_request(:get, "http://openid-provider/v1/attributes/test_attribute_1").to_return(status: 404)
      stub_request(:post, "http://openid-provider/v1/attributes").to_return(status: 200)
    end
  end

  provider_state "there is a valid user session, with saved pages" do
    set_up do
      FactoryBot.create_list(:saved_page, 2, oidc_user_id: oidc_user.id)
    end
  end

  provider_state "there is a valid user session, with /guidance/some-govuk-guidance saved" do
    set_up do
      stub_request(:get, "http://openid-provider/v1/attributes/email").to_return(status: 200, body: { claim_value: "user@example.com" }.to_json)
      stub_request(:get, "http://openid-provider/v1/attributes/email_verified").to_return(status: 200, body: { claim_value: true }.to_json)
      stub_request(:get, "http://openid-provider/v1/attributes/transition_checker_state").to_return(status: 404)
      FactoryBot.create(:saved_page, page_path: "/guidance/some-govuk-guidance", oidc_user_id: oidc_user.id)
    end
  end

  provider_state "there is a valid user session, with a transition checker email subscription" do
    set_up do
      stub_request(:get, "#{Plek.find('account-manager')}/api/v1/transition-checker/email-subscription").to_return(status: 204)
    end
  end

  provider_state "there is a valid user session, with an attribute called 'foo'" do
    set_up do
      stub_request(:get, "http://openid-provider/v1/attributes/foo").to_return(status: 200, body: { claim_value: { bar: "baz" } }.to_json)
    end
  end

  provider_state "there is a valid user session, with an attribute called 'test_attribute_1'" do
    set_up do
      stub_request(:get, "http://openid-provider/v1/attributes/test_attribute_1").to_return(status: 200, body: { claim_value: { bar: "baz" } }.to_json)
    end
  end
end
