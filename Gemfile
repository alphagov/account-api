# frozen_string_literal: true

source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "~> 3.3.1"

gem "rails", "7.2.2"

gem "attr_required"
gem "bootsnap", require: false
gem "dalli"
gem "gds-api-adapters"
gem "gds-sso"
gem "govuk_app_config"
gem "govuk_personalisation"
gem "govuk_publishing_components"
gem "govuk_sidekiq"
gem "json-jwt"
gem "notifications-ruby-client"
gem "openid_connect"
gem "pg"
gem "sentry-sidekiq"

# https://github.com/moove-it/sidekiq-scheduler/issues/345
gem "sidekiq-scheduler", "5.0.6"

group :development, :test do
  gem "awesome_print"
  gem "bullet"
  gem "database_cleaner-active_record"
  gem "factory_bot_rails"
  gem "govuk_schemas"
  gem "govuk_test"
  gem "listen"
  gem "pact", require: false
  gem "pact_broker-client"
  gem "pry-byebug"
  gem "pry-rails"
  gem "rspec-rails"
  gem "rubocop-govuk"
end

group :test do
  gem "shoulda-matchers"
  gem "simplecov"
  gem "webmock"
end
