# frozen_string_literal: true

source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby File.read(".ruby-version").strip

gem "rails", "6.1.4"

gem "bootsnap"
gem "dalli"
gem "gds-api-adapters"
gem "gds-sso"
gem "govuk_app_config"
gem "govuk_message_queue_consumer"
gem "govuk_sidekiq"
gem "openid_connect"
gem "pg"

# https://github.com/moove-it/sidekiq-scheduler/issues/345
gem "sidekiq-scheduler", "3.0.1"

group :development, :test do
  gem "awesome_print"
  gem "bullet"
  gem "database_cleaner-active_record"
  gem "factory_bot_rails"
  gem "govuk_schemas"
  gem "govuk_test"
  gem "pact", require: false
  gem "pact_broker-client"
  gem "pry-byebug"
  gem "pry-rails"
  gem "rspec-rails"
  gem "rubocop-govuk"
end

group :development do
  gem "listen"
end

group :test do
  gem "shoulda-matchers"
  gem "simplecov"
  gem "webmock"
end
