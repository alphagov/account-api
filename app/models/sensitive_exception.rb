class SensitiveException < ApplicationRecord
  EXPIRATION_AGE = 14.days
  scope :expired, -> { where("created_at < ?", EXPIRATION_AGE.ago) }
end
