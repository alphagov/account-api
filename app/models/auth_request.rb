class AuthRequest < ApplicationRecord
  EXPIRATION_AGE = 2.hours
  scope :expired, -> { where("created_at < ?", EXPIRATION_AGE.ago) }

  validates :redirect_path, absolute_path: true

  def self.generate!(options = {})
    create!(
      oauth_state: options[:oauth_state] || SecureRandom.hex(16),
      oidc_nonce: SecureRandom.hex(16),
      redirect_path: options[:redirect_path],
    )
  end

  # This has to be something which the account manager can use to retrieve a JWT, if there is one:
  # https://github.com/alphagov/govuk-account-manager-prototype/blob/6a68e02055fe3c70083b3899b474b10cc944ffa5/config/initializers/doorkeeper.rb#L14
  def to_oauth_state
    "#{oauth_state}:#{id}"
  end

  def self.from_oauth_state(state)
    bits = state.split(":")
    return nil unless bits.length == 2

    find_by(id: bits[1], oauth_state: bits[0])
  end
end
