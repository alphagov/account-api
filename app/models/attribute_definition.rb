class AttributeDefinition < OpenStruct
  include ActiveModel::Validations

  validates :type, presence: true
  validates :type, inclusion: %w[local remote cached]
  validates :check_requires_mfa, :get_requires_mfa, :set_requires_mfa, :writable, exclusion: [nil]
  validate :check_mfa_implies_get_mfa
  validate :get_mfa_implies_set_mfa_if_writable

  def initialize(type:, writable: true, check_requires_mfa: false, get_requires_mfa: false, set_requires_mfa: false)
    super
  end

  def check_mfa_implies_get_mfa
    errors.add(:check_requires_mfa, "implies :get_requires_mfa") if check_requires_mfa && !get_requires_mfa
  end

  def get_mfa_implies_set_mfa_if_writable
    return unless writable

    errors.add(:get_requires_mfa, "implies :set_requires_mfa") if get_requires_mfa && !set_requires_mfa
  end
end
