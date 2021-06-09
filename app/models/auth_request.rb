class AuthRequest < ApplicationRecord
  EXPIRATION_AGE = 2.hours
  scope :expired, -> { where("created_at < ?", EXPIRATION_AGE.ago) }

  validate :redirect_path_is_safe

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

  def redirect_path_is_safe
    return if redirect_path.nil?
    return if redirect_path.empty?

    if redirect_path.starts_with? "//"
      errors.add(:redirect_path, "can't be protocol-relative")
      return
    end

    return if redirect_path.starts_with? "/"
    return if redirect_path.starts_with?("http://") && Rails.env.development?

    errors.add(:redirect_path, "can't be absolute")
  end
end
