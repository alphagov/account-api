# frozen_string_literal: true

require "gds_api/publishing_api/special_route_publisher"

class PublishingApiTasks
  PUBLISHING_APP = "account-api"
  LOCALE = "en"

  attr_reader :content_items

  def initialize(publishing_api: nil, logger: nil, content_items: nil)
    @logger = logger || Logger.new($stdout)
    @publishing_api = publishing_api || GdsApi.publishing_api
    @content_items = content_items || YAML.safe_load(File.read(Rails.root.join("config/content_items.yml"))).deep_symbolize_keys
  end

  def publish_help_page(name)
    content_item = @content_items[:help_pages].fetch(name.to_sym)
    content_id = content_item.fetch(:content_id)
    base_path = content_item.fetch(:base_path)
    payload =
      {
        document_type: "help_page",
        schema_name: "help_page",
        rendering_app: content_item.fetch(:rendering_app),
        base_path: base_path,
        title: content_item.fetch(:title),
        description: content_item.fetch(:description),
        details: {
          body: [
            {
              content_type: "text/html",
              content: ActionController::Base.render(template: "help_pages/#{name}"),
            },
          ],
        },
        routes: [
          {
            path: content_item.fetch(:base_path),
            type: "exact",
          },
        ],
      }

    claim_path base_path
    publish_content_item(content_id, payload, "major")
  end

  def publish_redirects
    @content_items[:redirects].each do |redirect|
      base_path = redirect.fetch(:base_path)
      payload =
        {
          document_type: "redirect",
          schema_name: "redirect",
          base_path: base_path,
          redirects: [
            {
              path: base_path,
              destination: redirect.fetch(:destination),
              type: "exact",
            },
          ],
        }

      claim_path base_path
      publish_content_item(redirect.fetch(:content_id), payload, "major")
    end
  end

  def publish_special_route(content_id)
    publisher = GdsApi::PublishingApi::SpecialRoutePublisher.new(
      publishing_api: @publishing_api,
      logger: @logger,
    )

    special_route = @content_items[:special_routes].find { |route| route[:content_id] == content_id }

    if special_route.nil?
      puts "No special route found with content_id: #{content_id}"
      puts "Check files stored in: https://github.com/alphagov/account-api/blob/main/config/content_items.yml"
      return
    end

    claim_path special_route.fetch(:base_path)

    publisher.publish(
      special_route.merge(
        publishing_app: PUBLISHING_APP,
        type: "exact",
      ),
    )
  end

  def publish_special_routes
    publisher = GdsApi::PublishingApi::SpecialRoutePublisher.new(
      publishing_api: @publishing_api,
      logger: @logger,
    )

    @content_items[:special_routes].each do |special_route|
      claim_path special_route.fetch(:base_path)

      publisher.publish(
        special_route.merge(
          publishing_app: PUBLISHING_APP,
          type: "exact",
        ),
      )
    end
  end

  def claim_path(base_path)
    @logger.info("Claiming ownership of route #{base_path}")
    @publishing_api.put_path(
      base_path,
      publishing_app: PUBLISHING_APP,
      override_existing: true,
    )
  end

  def publish_content_item(content_id, payload, update_type)
    @logger.info("Publishing content for #{payload.fetch(:base_path)}")
    @publishing_api.put_content(
      content_id,
      payload.merge(publishing_app: PUBLISHING_APP, locale: LOCALE, update_type: update_type),
    )
    @publishing_api.publish(content_id, update_type, locale: LOCALE)
  end
end
