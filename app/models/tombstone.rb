class Tombstone < ApplicationRecord
  validates :sub, presence: true

  EXPIRATION_AGE = 30.days
  scope :expired, -> { where("created_at < ?", EXPIRATION_AGE.ago) }
end
