require_relative "../message_queue_processor.rb"

namespace :message_queue do
  desc "Run worker to consume messages from RabbitMQ"
  task consumer: :environment do
    GovukMessageQueueConsumer::Consumer.new(
      queue_name: "account_api",
      processor: MessageQueueProcessor.new,
    ).run
  end
end
