class ExpiredTombstoneJob < ApplicationJob
  def perform
    Tombstone.expired.delete_all
  end
end
