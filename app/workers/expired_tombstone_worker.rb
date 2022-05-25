class ExpiredTombstoneWorker < ApplicationWorker
  def perform
    Tombstone.expired.delete_all
  end
end
