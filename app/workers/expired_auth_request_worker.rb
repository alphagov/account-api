class ExpiredAuthRequestWorker < ApplicationWorker
  def perform
    AuthRequest.expired.delete_all
  end
end
