class OidcUser < ApplicationRecord
  has_many :local_attributes, dependent: :destroy
  has_many :saved_pages, dependent: :destroy
end
