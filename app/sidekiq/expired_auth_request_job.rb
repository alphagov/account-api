class ExpiredAuthRequestJob < ApplicationJob
  def perform
    AuthRequest.expired.delete_all
  end
end
