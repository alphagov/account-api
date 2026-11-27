require "active_support/core_ext/object/blank"
require "rackup/handler/webrick"
Rackup::Handler::WEBrick::Input.class_eval { def rewind; end unless method_defined?(:rewind) }
require "webmock"

require "rails_helper"
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

  def oidc_user
    OidcUser.find_or_create_by_sub!("user-id")
  end
end
