require "gds_api/publishing_api/special_route_publisher"

class PublishingApiTasks
  def initialize(publishing_api: nil, logger: nil, content_items: nil)
    @logger = logger || Logger.new($stdout)
    @publishing_api = publishing_api || GdsApi.publishing_api
    @content_items = content_items || YAML.safe_load(File.read(Rails.root.join("config/content_items.yml"))).deep_symbolize_keys
  end

  def publish_help_page(name)
    content_item = @content_items[:help_pages].fetch(name.to_sym)
    content_id = content_item.fetch(:content_id)
    base_path = content_item.fetch(:base_path)

    claim_path base_path

    @logger.info("Publishing content for #{base_path}")
    @publishing_api.put_content(
      content_id,
      {
        update_type: "major",
        document_type: "help_page",
        schema_name: "help_page",
        publishing_app: "account-api",
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
      },
    )
    @publishing_api.publish(content_id, "major")
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
