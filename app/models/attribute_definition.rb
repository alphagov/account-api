class AttributeDefinition < OpenStruct
  include ActiveModel::Validations

  validates :type, :level_of_auth_check, :level_of_auth_get, :level_of_auth_set, presence: true
  validates :type, inclusion: %w[local remote cached]
  validates :writable, exclusion: [nil]
  validate :auth_ordering

  def initialize(type:, writable: true, level_of_auth_check: 0, level_of_auth_get: 0, level_of_auth_set: 0)
    super
  end

  def auth_ordering
    if level_of_auth_get && level_of_auth_check && level_of_auth_get < level_of_auth_check
      errors.add(:level_of_auth_check, "must be <= :level_of_auth_get")
    end

    if writable && level_of_auth_get && level_of_auth_set && level_of_auth_set < level_of_auth_get
      errors.add(:level_of_auth_get, "must be <= :level_of_auth_set")
    end
  end
end
