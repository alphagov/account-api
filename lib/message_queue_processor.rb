# TODO: revisit whether we'll need to consume publishing updates after implementing single-page notifications
class MessageQueueProcessor
  def process(message)
    message.ack
  end
end
