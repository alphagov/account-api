require "webmock"
require "pact/provider/rspec"
require "plek"
require "gds_api/test_helpers/content_store"
require "gds_api/test_helpers/email_alert_api"

Dir["./spec/support/**/*.rb"].sort.each { |f| require f }

module PactStubHelpers
  EMAIL_ADDRESS = "user@example.com".freeze

  def stub_email_attribute_requests(email_verified: true, has_unconfirmed_email: false)
    stub_remote_attribute_requests(
      email: EMAIL_ADDRESS,
      email_verified: email_verified,
      has_unconfirmed_email: has_unconfirmed_email,
    )
  end

  def stub_will_create_email_subscription(topic_slug, subscriber_list_id: "list-id")
    stub_email_alert_api_has_subscriber_list_by_slug(
      slug: topic_slug,
      returned_attributes: { id: subscriber_list_id },
    )

    stub_email_alert_api_creates_a_subscription(
      subscriber_list_id: subscriber_list_id,
      address: EMAIL_ADDRESS,
      frequency: "daily",
      returned_subscription_id: "subscription-id",
      skip_confirmation_email: true,
    )
  end
end

def oidc_user
  OidcUser.find_or_create_by(sub: "user-id")
end

def url_encode(str)
  ERB::Util.url_encode(str)
end

Pact.configure do |config|
  config.reports_dir = "spec/reports/pacts"
  config.include PactStubHelpers
  config.include GdsApi::TestHelpers::ContentStore
  config.include GdsApi::TestHelpers::EmailAlertApi
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
    stub_userinfo

    account_session = placeholder_govuk_account_session_object(
      user_id: oidc_user.sub,
      level_of_authentication: "level1",
    )
    allow(AccountSession).to receive(:deserialise).and_return(account_session)

    normal_file = YAML.safe_load(File.read(Rails.root.join("config/user_attributes.yml"))).with_indifferent_access
    fixture_file = YAML.safe_load(File.read(Rails.root.join("spec/fixtures/user_attributes.yml"))).with_indifferent_access
    allow(UserAttributes).to receive(:load_config_file).and_return(normal_file.merge(fixture_file))

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

  provider_state "there is a valid OAuth response, with cookie consent 'true'" do
    set_up do
      auth_request = AuthRequest.generate!(redirect_path: "/some-arbitrary-path")
      allow(AuthRequest).to receive(:from_oauth_state).and_return(auth_request)

      stub_request(:get, "#{Plek.find('account-manager')}/api/v1/ephemeral-state").to_return(status: 200, body: { _ga: "ga-client-id", level_of_authentication: "level0", cookie_consent: true }.to_json)
    end
  end

  provider_state "there is a valid user session" do
    set_up do
      stub_email_attribute_requests
      stub_will_create_email_subscription "wizard-news-topic-slug"
      stub_remote_attribute_requests(test_attribute_1: nil)
      stub_request(:post, "http://openid-provider/v1/attributes").to_return(status: 200)
    end
  end

  provider_state "there is a valid user session, with a 'wizard-news' email subscription" do
    set_up do
      stub_email_attribute_requests
      stub_will_create_email_subscription "wizard-news-topic-slug"
      FactoryBot.create(:email_subscription, name: "wizard-news", oidc_user_id: oidc_user.id)
    end
  end

  provider_state "there is a valid user session, with saved pages" do
    set_up do
      FactoryBot.create_list(:saved_page, 2, oidc_user_id: oidc_user.id)
    end
  end

  # TODO: remove when gds-api-adapters PR is merged
  provider_state "there is a valid user session, with /guidance/some-govuk-guidance saved" do
    set_up do
      stub_email_attribute_requests
      FactoryBot.create(:saved_page, page_path: "/guidance/some-govuk-guidance", oidc_user_id: oidc_user.id)
    end
  end

  provider_state "there is a valid user session, with '/guidance/some-govuk-guidance' saved" do
    set_up do
      stub_email_attribute_requests
      FactoryBot.create(:saved_page, page_path: "/guidance/some-govuk-guidance", oidc_user_id: oidc_user.id)
    end
  end

  # TODO: remove when gds-api-adapters PR is merged
  provider_state "there is a valid user session, with an attribute called 'foo'" do
    set_up do
      stub_remote_attribute_request(name: "foo", value: { bar: "baz" })
    end
  end

  provider_state "there is a valid user session, with an attribute called 'test_attribute_1'" do
    set_up do
      stub_remote_attribute_request(name: "test_attribute_1", value: { bar: "baz" })
    end
  end
end
