require "gds_api/publishing_api/special_route_publisher"

class PublishingApiTasks
  def initialize(publishing_api: nil, logger: nil, content_items: nil)
    @logger = logger || Logger.new($stdout)
    @publishing_api = publishing_api || GdsApi.publishing_api
    @content_items = content_items || YAML.safe_load(File.read(Rails.root.join("config/content_items.yml"))).deep_symbolize_keys
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
          publishing_app: "account-api",
          type: "exact",
        ),
      )
    end
  end

  def claim_path(base_path)
    @logger.info("Claiming ownership of route #{base_path}")
    @publishing_api.put_path(
      base_path,
      publishing_app: "account-api",
      override_existing: true,
    )
  end
end
