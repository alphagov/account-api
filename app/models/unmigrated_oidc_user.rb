class UnmigratedOidcUser < ApplicationRecord
  validates :sub, presence: true
end
