class AuthRequest < ApplicationRecord
  EXPIRATION_AGE = 2.hours
  scope :expired, -> { where("created_at < ?", EXPIRATION_AGE.ago) }

  validates :oauth_state, presence: true
  validates :oidc_nonce, presence: true
  validates :redirect_path, absolute_path_with_query_string: true

  def self.generate!(redirect_path: nil)
    create!(
      oauth_state: SecureRandom.hex(16),
      oidc_nonce: SecureRandom.hex(16),
      redirect_path: redirect_path,
    )
  end

  def to_oauth_state
    "#{oauth_state}:#{id}"
  end

  def self.from_oauth_state(state)
    bits = state.split(":")
    return nil unless bits.length == 2

    find_by(id: bits[1], oauth_state: bits[0])
  end
end
