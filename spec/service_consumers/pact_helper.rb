require "webmock"
require "pact/provider/rspec"
require "plek"
require "gds_api/test_helpers/content_store"
require "gds_api/test_helpers/email_alert_api"

Dir["./spec/support/**/*.rb"].sort.each { |f| require f }

module PactStubHelpers
  EMAIL_ADDRESS = "user@example.com".freeze

  def stub_cached_attributes(email_verified: true)
    oidc_user.update!(
      email: EMAIL_ADDRESS,
      email_verified:,
    )
  end
end

def oidc_user
  OidcUser.find_or_create_by_sub!("user-id")
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
      version_modifier = "versions/#{url_encode(ENV.fetch('PACT_CONSUMER_VERSION', 'branch-main'))}"

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

    allow(Rails.application.secrets).to receive(:oauth_client_private_key).and_return(nil)

    stub_oidc_discovery
    stub_token_response
    stub_userinfo

    account_session = placeholder_govuk_account_session_object(
      user_id: oidc_user.sub,
      mfa: true,
    )
    allow(AccountSession).to receive(:deserialise).and_return(account_session)

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
      stub_cached_attributes
    end
  end

  provider_state "there is a valid OAuth response, with the redirect path '/some-arbitrary-path'" do
    set_up do
      auth_request = AuthRequest.generate!(redirect_path: "/some-arbitrary-path")
      allow(AuthRequest).to receive(:from_oauth_state).and_return(auth_request)
      stub_cached_attributes
    end
  end

  provider_state "there is a valid OAuth response, with cookie consent 'true'" do
    set_up do
      auth_request = AuthRequest.generate!(redirect_path: "/some-arbitrary-path")
      allow(AuthRequest).to receive(:from_oauth_state).and_return(auth_request)
      stub_cached_attributes
      oidc_user.update!(cookie_consent: true)
    end
  end

  provider_state "there is a valid user session" do
    set_up do
      stub_cached_attributes
      # rubocop:disable RSpec/AnyInstance
      allow_any_instance_of(AccountSession).to receive(:set_remote_attributes)
      # rubocop:enable RSpec/AnyInstance
    end
  end

  provider_state "there is a valid user session, with an attribute called 'email'" do
    set_up do
      stub_cached_attributes
      oidc_user.update!(email: "email@example.com")
    end
  end

  provider_state "there is a user with subject identifier 'the-subject-identifier'" do
    set_up do
      user = FactoryBot.create(:oidc_user, sub: "the-subject-identifier")
      stub_request(:get, "#{GdsApi::TestHelpers::EmailAlertApi::EMAIL_ALERT_API_ENDPOINT}/subscribers/govuk-account/#{user.id}").to_return(status: 404)
    end
  end

  provider_state "there is a user with email address 'email@example.com'" do
    set_up do
      FactoryBot.create(:oidc_user, email: "email@example.com")
    end
  end
end
