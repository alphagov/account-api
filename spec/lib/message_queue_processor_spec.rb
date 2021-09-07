require "message_queue_processor"

require "gds_api/test_helpers/content_store"
require "govuk_message_queue_consumer/test_helpers"

RSpec.describe MessageQueueProcessor do
  include GdsApi::TestHelpers::ContentStore

  it_behaves_like "a message queue processor"

  it "acks incoming messages" do
    payload = GovukSchemas::RandomExample.for_schema(notification_schema: "guide")
    message = GovukMessageQueueConsumer::MockMessage.new(payload)
    described_class.new.process(message)
    expect(message).to be_acked
  end

  describe "process_message" do
    subject(:actual_output) { described_class.new.process_message(payload) }

    let(:payload) { GovukSchemas::RandomExample.for_schema(notification_schema: "guide") }
    let(:content_item) { payload }

    let!(:saved_page) { FactoryBot.create(:saved_page, content_id: payload["content_id"], page_path: payload["base_path"] || "/example-page") }

    let(:expected_output) do
      {
        type: payload["document_type"],
        base_path: payload["base_path"],
        content_id: payload["content_id"],
        affected_pages: 1,
        effect: expected_effect,
      }
    end

    let(:expected_effect) { "updated" }

    let(:expected_to_hash) do
      {
        "content_id" => content_item["content_id"],
        "page_path" => content_item["base_path"],
        "title" => content_item["title"],
        "public_updated_at" => JSON.parse(Time.zone.parse(content_item["public_updated_at"]).to_json),
      }
    end

    it "updates the page attributes" do
      expect(actual_output).to eq(expected_output)
      expect(saved_page.reload.to_hash).to eq(expected_to_hash)
    end

    shared_examples "redirection" do
      context "when the redirect target exists" do
        before { stub_content_store_has_item(alternative_path, content_item) }

        let(:expected_effect) { "redirected 1 to #{alternative_path} and destroyed 0 duplicates" }

        it "updates matching pages" do
          expect(actual_output).to eq(expected_output)
          expect(saved_page.reload.to_hash).to eq(expected_to_hash)
        end
      end

      context "when the redirect target does not exist" do
        before { stub_content_store_does_not_have_item(alternative_path, content_item) }

        let(:expected_effect) { "destroyed" }

        it "destroys matching pages" do
          expect(actual_output).to eq(expected_output)
          expect { saved_page.reload }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end

      context "when the redirect target has been marked 'gone'" do
        before { stub_content_store_has_gone_item(alternative_path, content_item) }

        let(:expected_effect) { "destroyed" }

        it "destroys matching pages" do
          expect(actual_output).to eq(expected_output)
          expect { saved_page.reload }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end
    end

    context "with a 'gone' notification" do
      let(:alternative_path) { nil }
      let(:expected_effect) { "destroyed" }

      let(:payload) do
        GovukSchemas::RandomExample.for_schema(notification_schema: "gone") do |payload|
          payload["details"] ||= {}
          payload["details"] = payload["details"].merge("alternative_path" => alternative_path).compact
          payload
        end
      end

      it "destroys matching pages" do
        expect(actual_output).to eq(expected_output)
        expect { saved_page.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end

      context "with an alternative path" do
        let(:alternative_path) { "/alternative-path" }
        let(:content_item) { content_item_for_base_path(alternative_path).merge("content_id" => SecureRandom.uuid) }

        include_examples "redirection"
      end
    end

    context "with a 'redirect' notification" do
      let(:alternative_path) { "/alternative-path" }
      let(:content_item) { content_item_for_base_path(alternative_path).merge("content_id" => SecureRandom.uuid) }

      let(:payload) do
        GovukSchemas::RandomExample.for_schema(notification_schema: "redirect") do |payload|
          payload.merge(
            "redirects" => [{ "path" => payload["base_path"], "type" => "exact", "destination" => alternative_path }],
          )
        end
      end

      include_examples "redirection"
    end

    context "with a 'vanish' notification" do
      let(:payload) { GovukSchemas::RandomExample.for_schema(notification_schema: "vanish") }
      let(:expected_effect) { "destroyed" }

      it "destroys matching pages" do
        expect(actual_output).to eq(expected_output)
        expect { saved_page.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe "find_alternative_path" do
    subject(:alternative_path) { described_class.new.find_alternative_path(payload) }

    let(:payload) { { "base_path" => "/base/path", "details" => details, "redirects" => redirects }.compact }
    let(:details) { { "alternative_path" => "/alternative-path" } }
    let(:redirects) { [exact_redirect, prefix_redirect].compact }
    let(:exact_redirect) { { "type" => "exact", "path" => "/base/path", "destination" => "/exact-redirect" } }
    let(:prefix_redirect) { { "type" => "prefix", "path" => "/base", "destination" => "/prefix-redirect" } }

    it "uses the alternative_path" do
      expect(alternative_path).to eq(details["alternative_path"])
    end

    context "when there is no alternative_path" do
      let(:details) { nil }

      it "uses the exact redirect" do
        expect(alternative_path).to eq(exact_redirect["destination"])
      end

      context "when the exact redirect is for a different path" do
        let(:exact_redirect) { { "type" => "exact", "path" => "/some/path2", "destination" => "/exact-redirect" } }

        it "uses the prefix redirect" do
          expect(alternative_path).to eq(prefix_redirect["destination"])
        end
      end

      context "when there is no exact redirect" do
        let(:exact_redirect) { nil }

        it "uses the prefix redirect" do
          expect(alternative_path).to eq(prefix_redirect["destination"])
        end

        context "when segments_mode is 'preserve'" do
          let(:prefix_redirect) { { "type" => "prefix", "path" => "/base", "destination" => "/prefix-redirect", "segments_mode" => "preserve" } }

          it "keeps the trailing bits of the path" do
            expect(alternative_path).to eq("/prefix-redirect/path")
          end
        end

        context "when there are multiple matching prefix redirects" do
          let(:redirects) do
            [
              { "type" => "prefix", "path" => "/base", "destination" => "/prefix-redirect-0" },
              { "type" => "prefix", "path" => "/base/path", "destination" => "/prefix-redirect-1" },
              { "type" => "prefix", "path" => "/base/path/inner", "destination" => "/prefix-redirect-1" },
            ]
          end

          it "uses the most specific matching one" do
            expect(alternative_path).to eq("/prefix-redirect-1")
          end
        end

        context "when the prefix redirect is for a different path" do
          let(:prefix_redirect) { { "type" => "prefix", "path" => "/base2", "destination" => "/prefix-redirect" } }

          it "returns nil" do
            expect(alternative_path).to be_nil
          end
        end

        context "when there is no prefix redirect" do
          let(:prefix_redirect) { nil }

          it "returns nil" do
            expect(alternative_path).to be_nil
          end
        end

        context "when there are no redirects at all" do
          let(:redirects) { nil }

          it "returns nil" do
            expect(alternative_path).to be_nil
          end
        end
      end
    end
  end

  describe "redirect_saved_pages" do
    subject(:effect) { described_class.new.redirect_saved_pages(saved_pages, alternative_path) }

    let(:alternative_path) { "/alternative-path" }
    let(:content_id) { SecureRandom.uuid }
    let(:title) { "Hello World" }
    let(:saved_pages) do
      [
        FactoryBot.create(:saved_page, page_path: "/foo"),
        FactoryBot.create(:saved_page, page_path: "/foo"),
        FactoryBot.create(:saved_page, page_path: "/foo"),
      ]
    end

    before do
      stub_content_store_has_item(
        alternative_path,
        content_item_for_base_path(alternative_path).merge("content_id" => content_id, "title" => title),
      )
    end

    it "updates the page paths" do
      expect(effect).to eq("redirected 3 to #{alternative_path} and destroyed 0 duplicates")

      saved_pages.each do |page|
        expect(page.reload.content_id).to eq(content_id)
        expect(page.reload.page_path).to eq(alternative_path)
        expect(page.reload.title).to eq(title)
      end
    end

    context "with duplicate pages" do
      let(:user) { FactoryBot.create(:oidc_user) }
      let(:saved_pages) do
        [
          FactoryBot.create(:saved_page, page_path: "/foo"),
          FactoryBot.create(:saved_page, page_path: "/foo", oidc_user: user),
          FactoryBot.create(:saved_page, page_path: alternative_path, oidc_user: user),
        ]
      end

      it "destroys duplicate pages" do
        expect(effect).to eq("redirected 2 to #{alternative_path} and destroyed 1 duplicates")
        expect(SavedPage.all.pluck(:page_path)).to eq([alternative_path, alternative_path])
      end
    end
  end
end
