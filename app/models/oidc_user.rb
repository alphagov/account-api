class OidcUser < ApplicationRecord
  has_many :local_attributes, dependent: :destroy
end
