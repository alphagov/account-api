require "publishing_api_tasks"

require "gds_api/test_helpers/publishing_api"

RSpec.describe PublishingApiTasks do
  include GdsApi::TestHelpers::PublishingApi

  subject(:tasks) { described_class.new(logger:, content_items:) }

  let(:logger) { instance_double(Logger) }
  let(:content_items) { nil }

  describe "content item definitions" do
    subject(:content_items) { described_class.new.content_items }

    it "all have a unique content ID" do
      content_ids = {}
      content_items[:help_pages].each_value { |item| increment(content_ids, item[:content_id]) }
      content_items[:redirects].each { |item| increment(content_ids, item[:content_id]) }
      content_items[:special_routes].each { |item| increment(content_ids, item[:content_id]) }

      content_ids.each do |content_id, count|
        expect("#{content_id}: #{count}").to eq("#{content_id}: 1")
      end
    end

    it "all have a unique base path" do
      base_paths = {}
      content_items[:help_pages].each_value { |item| increment(base_paths, item[:base_path]) }
      content_items[:redirects].each { |item| increment(base_paths, item[:base_path]) }
      content_items[:special_routes].each { |item| increment(base_paths, item[:base_path]) }

      base_paths.each do |base_path, count|
        expect("#{base_path}: #{count}").to eq("#{base_path}: 1")
      end
    end

    def increment(hash, item)
      hash[item] = hash.fetch(item, 0) + 1
    end
  end

  describe "#publish_help_page" do
    before { allow(logger).to receive(:info) }

    let(:help_page_name) { "sign_in" }
    let(:help_page) { { content_id: SecureRandom.uuid, base_path: "/foo", title: "title", description: "description", rendering_app: "frontend" } }
    let(:content_items) { { help_pages: { help_page_name.to_sym => help_page } } }

    it "takes ownership of the route and publishes the content item" do
      stub_claim_path = stub_call_claim_path(help_page[:base_path])
      stub_put_content = stub_call_put_content(help_page[:content_id], help_page.except(:content_id), "major")
      stub_publish = stub_call_publish(help_page[:content_id], "major")

      tasks.publish_help_page(help_page_name)

      expect(stub_claim_path).to have_been_made
      expect(stub_put_content).to have_been_made
      expect(stub_publish).to have_been_made
    end
  end

  describe "#publish_redirects" do
    before { allow(logger).to receive(:info) }

    let(:redirect) { { content_id: SecureRandom.uuid, base_path: "/foo", destination: "/bar" } }
    let(:content_items) { { redirects: [redirect] } }

    it "takes ownership of the route and publishes the content item" do
      stub_claim_path = stub_call_claim_path(redirect[:base_path])
      stub_put_content = stub_call_put_content(redirect[:content_id], { redirects: [{ path: redirect[:base_path], destination: redirect[:destination], type: "exact" }] }, "major")
      stub_publish = stub_call_publish(redirect[:content_id], "major")

      tasks.publish_redirects

      expect(stub_claim_path).to have_been_made
      expect(stub_put_content).to have_been_made
      expect(stub_publish).to have_been_made
    end
  end

  describe "#publish_special_route" do
    before { allow(logger).to receive(:info) }

    let(:content_id) { SecureRandom.uuid }
    let(:special_route) { { content_id:, base_path: "/foo", title: "title", rendering_app: "frontend" } }
    let(:content_items) { { special_routes: [special_route] } }

    it "takes ownership of the route and publishes the content item" do
      stub_claim_path = stub_call_claim_path(special_route[:base_path])
      stub_put_content = stub_call_put_content(special_route[:content_id], special_route.except(:content_id), "major")
      stub_publish = stub_call_publish(special_route[:content_id], "major")

      tasks.publish_special_route(content_id)

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
      stub_claim_path = stub_call_claim_path(special_route[:base_path])
      stub_put_content = stub_call_put_content(special_route[:content_id], special_route.except(:content_id), "major")
      stub_publish = stub_call_publish(special_route[:content_id], "major")

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
      stub = stub_call_claim_path(path)

      tasks.claim_path(path)

      expect(stub).to have_been_made
    end
  end

  describe "#publish_content_item" do
    before { allow(logger).to receive(:info).with(/Publishing/) }

    let(:content_id) { SecureRandom.uuid }
    let(:payload) { { base_path: "/foo", title: "title", description: "description" } }
    let(:update_type) { "like, super major" }

    it "puts the content and then publishes it" do
      stub_put_content = stub_call_put_content(content_id, payload, update_type)
      stub_publish = stub_call_publish(content_id, update_type)

      tasks.publish_content_item(content_id, payload, update_type)

      expect(stub_put_content).to have_been_made
      expect(stub_publish).to have_been_made
    end
  end

  def stub_call_claim_path(path)
    stub_publishing_api_path_reservation(path, publishing_app: "account-api", override_existing: true)
  end

  def stub_call_put_content(content_id, payload, update_type)
    stub_publishing_api_put_content(content_id, hash_including(payload.merge(publishing_app: "account-api", locale: "en", update_type:)))
  end

  def stub_call_publish(content_id, update_type)
    stub_publishing_api_publish(content_id, { update_type:, locale: "en" })
  end
end
