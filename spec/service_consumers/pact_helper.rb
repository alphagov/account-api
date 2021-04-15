require "webmock"
require "pact/provider/rspec"

Pact.configure do |config|
  config.reports_dir = "spec/reports/pacts"
  config.include WebMock::API
  config.include WebMock::Matchers
end

def url_encode(str)
  ERB::Util.url_encode(str)
end

Pact.service_provider "Account API" do
  honours_pact_with "GDS API Adapters" do
    if ENV["PACT_URI"]
      pact_uri ENV["PACT_URI"]
    else
      base_url = "https://pact-broker.cloudapps.digital"
      path = "pacts/provider/#{url_encode(name)}/consumer/#{url_encode(consumer_name)}"
      version_modifier = "versions/#{url_encode(ENV.fetch('GDS_API_ADAPTERS_PACT_VERSION', 'master'))}"

      pact_uri("#{base_url}/#{path}/#{version_modifier}")
    end
  end
end

Pact.provider_states_for "GDS API Adapters" do
  set_up do
    ENV["GOVUK_ACCOUNT_OAUTH_CLIENT_ID"] = "client-id"
    ENV["GOVUK_ACCOUNT_OAUTH_CLIENT_SECRET"] = "client-secret"

    WebMock.enable!
    WebMock.reset!

    discovery_response = instance_double(
      "OpenIDConnect::Discovery::Provider::Config::Response",
      authorization_endpoint: "http://openid-provider/authorization-endpoint",
      token_endpoint: "http://openid-provider/token-endpoint",
      userinfo_endpoint: "http://openid-provider/userinfo-endpoint",
      end_session_endpoint: "http://openid-provider/end-session-endpoint",
    )

    # rubocop:disable RSpec/AnyInstance
    allow_any_instance_of(OidcClient).to receive(:discover).and_return(discovery_response)
    allow_any_instance_of(OidcClient).to receive(:tokens!).and_return({ access_token: "access-token", refresh_token: "refresh-token" })
    allow_any_instance_of(ApplicationController).to receive(:from_account_session).and_return({ access_token: "access-token", refresh_token: "refresh-token" })
    # rubocop:enable RSpec/AnyInstance

    stub_request(:post, Plek.find("account-manager") + "/api/v1/jwt").to_return(status: 200, body: { id: "jwt-id" }.to_json)
  end

  tear_down do
    WebMock.disable!
  end

  provider_state "there is a valid OAuth response" do
    set_up do
      auth_request = AuthRequest.generate!
      allow(AuthRequest).to receive(:from_oauth_state).and_return(auth_request)

      stub_request(:get, Plek.find("account-manager") + "/api/v1/ephemeral-state").to_return(status: 200, body: { _ga: "ga-client-id", level_of_authentication: "level0" }.to_json)
    end
  end

  provider_state "there is a valid OAuth response, with the redirect path '/some-arbitrary-path'" do
    set_up do
      auth_request = AuthRequest.generate!(redirect_path: "/some-arbitrary-path")
      allow(AuthRequest).to receive(:from_oauth_state).and_return(auth_request)

      stub_request(:get, Plek.find("account-manager") + "/api/v1/ephemeral-state").to_return(status: 200, body: { _ga: "ga-client-id", level_of_authentication: "level0" }.to_json)
    end
  end

  provider_state "there is a valid user session" do
    set_up do
      stub_request(:get, Plek.find("account-manager") + "/api/v1/transition-checker/email-subscription").to_return(status: 404)
      stub_request(:post, Plek.find("account-manager") + "/api/v1/transition-checker/email-subscription").to_return(status: 200)
      stub_request(:get, "http://openid-provider/v1/attributes/foo").to_return(status: 404)
      stub_request(:post, "http://openid-provider/v1/attributes").to_return(status: 200)
    end
  end

  provider_state "there is a valid user session, with a transition checker email subscription" do
    set_up do
      stub_request(:get, Plek.find("account-manager") + "/api/v1/transition-checker/email-subscription").to_return(status: 204)
    end
  end

  provider_state "there is a valid user session, with an attribute called 'foo'" do
    set_up do
      stub_request(:get, "http://openid-provider/v1/attributes/foo").to_return(status: 200, body: { claim_value: { bar: "baz" } }.to_json)
    end
  end
end
