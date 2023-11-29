require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Check for common ActiveRecord performance problems
  config.after_initialize do
    Bullet.enable = true
    Bullet.bullet_logger = true
    Bullet.rails_logger = true
  end

  # In the development environment your application's code is reloaded any time
  # it changes. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.enable_reloading = true

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports.
  config.consider_all_requests_local = true

  # Enable server timing
  config.server_timing = true

  # Enable/disable caching. By default caching is disabled.
  # Run rails dev:cache to toggle caching.
  if Rails.root.join("tmp/caching-dev.txt").exist?
    config.cache_store = :memory_store
    config.public_file_server.headers = {
      "Cache-Control" => "public, max-age=#{2.days.to_i}",
    }
  else
    config.action_controller.perform_caching = false

    config.cache_store = :null_store
  end

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise exceptions for disallowed deprecations.
  config.active_support.disallowed_deprecation = :raise

  # Tell Active Support which deprecation messages to disallow.
  config.active_support.disallowed_deprecation_warnings = []

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load

  # Highlight code that triggered database queries in logs.
  config.active_record.verbose_query_logs = true

  # Raises error for missing translations.
  # config.i18n.raise_on_missing_translations = true

  # Annotate rendered view with file names.
  # config.action_view.annotate_rendered_view_with_filenames = true

  # Use an evented file watcher to asynchronously detect changes in source code,
  # routes, locales, etc. This feature depends on the listen gem.
  config.file_watcher = ActiveSupport::EventedFileUpdateChecker

  # Uncomment if you wish to allow Action Cable access from any origin.
  # config.action_cable.disable_request_forgery_protection = true

  # For govuk_personalisation's controller concern
  config.middleware.use ActionDispatch::Cookies

  # Allow requests for all domains, e.g. <app>.dev.gov.uk
  config.hosts.clear
end

# make discovery work over HTTP
module OpenIDConnect
  module Discovery
    module Provider
      class Config
        class Resource
          def initialize(uri)
            @host = uri.host
            @port = uri.port unless [80, 443].include?(uri.port)
            @path = File.join uri.path, ".well-known/openid-configuration"
            @scheme = uri.scheme
            attr_missing!
          end

          def endpoint
            SWD.url_builder = case @scheme
                              when "http"
                                URI::HTTP
                              else
                                URI::HTTPS
                              end
            SWD.url_builder.build [nil, host, port, path, nil, nil]
          rescue URI::Error => e
            raise SWD::Exception, e.message
          end
        end
      end
    end
  end
end
