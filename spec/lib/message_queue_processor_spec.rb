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
end
