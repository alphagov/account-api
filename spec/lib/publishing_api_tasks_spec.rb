require "publishing_api_tasks"

require "gds_api/test_helpers/publishing_api"

RSpec.describe PublishingApiTasks do
  include GdsApi::TestHelpers::PublishingApi

  subject(:tasks) { described_class.new(logger: logger, content_items: content_items) }

  let(:logger) { instance_double("Logger") }
  let(:content_items) { nil }

  describe "#publish_help_page" do
    before { allow(logger).to receive(:info) }

    let(:help_page_name) { "sign_in" }
    let(:help_page) { { content_id: SecureRandom.uuid, base_path: "/foo", title: "title", description: "description", rendering_app: "frontend" } }
    let(:content_items) { { help_pages: { help_page_name.to_sym => help_page } } }

    it "takes ownership of the route and publishes the content item" do
      stub_claim_path = stub_path_reservation(help_page[:base_path])
      stub_put_content = stub_publishing_api_put_content(
        help_page[:content_id],
        hash_including(help_page.merge(publishing_app: "account-api").except(:content_id)),
      )
      stub_publish = stub_publishing_api_publish(
        help_page[:content_id],
        hash_including(update_type: "major"),
      )

      tasks.publish_help_page(help_page_name)

      expect(stub_claim_path).to have_been_made
      expect(stub_put_content).to have_been_made
      expect(stub_publish).to have_been_made
    end
  end

  describe "#publish_special_routes" do
    before { allow(logger).to receive(:info) }

    let(:special_route) { { content_id: SecureRandom.uuid, base_path: "/foo", title: "title", rendering_app: "frontend" } }
    let(:content_items) { { special_routes: [special_route] } }

    it "takes ownership of the route and publishes the content item" do
      stub_claim_path = stub_path_reservation(special_route[:base_path])
      stub_put_content = stub_publishing_api_put_content(
        special_route[:content_id],
        hash_including(special_route.merge(publishing_app: "account-api").except(:content_id)),
      )
      stub_publish = stub_publishing_api_publish(
        special_route[:content_id],
        hash_including(update_type: "major"),
      )

      tasks.publish_special_routes

      expect(stub_claim_path).to have_been_made
      expect(stub_put_content).to have_been_made
      expect(stub_publish).to have_been_made
    end
  end

  describe "#claim_path" do
    before { allow(logger).to receive(:info).with(/Claiming/) }

    let(:path) { "/some/page" }

    it "takes ownership of the path, overriding any existing ownership" do
      stub = stub_path_reservation(path)
      tasks.claim_path(path)
      expect(stub).to have_been_made
    end
  end

  def stub_path_reservation(path)
    stub_publishing_api_path_reservation(path, publishing_app: "account-api", override_existing: true)
  end
end
