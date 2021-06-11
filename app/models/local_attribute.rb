class LocalAttribute < ApplicationRecord
  belongs_to :oidc_user

  validates :name, presence: true, uniqueness: { scope: :oidc_user_id }
  validates :value, exclusion: [nil]
end
