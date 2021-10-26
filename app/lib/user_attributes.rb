class UserAttributes
  attr_reader :attributes

  class UnknownPermission < StandardError; end

  def initialize(attributes = nil)
    @attributes = (attributes || Rails.configuration.x.user_attributes).transform_values do |config|
      AttributeDefinition.new(
        type: config[:type],
        writable: config.fetch(:writable, true),
        check_requires_mfa: config.fetch(:check_requires_mfa, false),
        get_requires_mfa: config.fetch(:get_requires_mfa, false),
        set_requires_mfa: config.fetch(:set_requires_mfa, false),
      )
    end
  end

  def defined?(name)
    attributes.key? name.to_sym
  end

  def type(name)
    fetch(name)[:type]
  end

  def is_writable?(name)
    fetch(name)[:writable]
  end

  def has_permission_for?(name, permission_level, user_session)
    if requires_mfa_for?(name, permission_level)
      user_session.mfa?
    else
      true
    end
  end

  def requires_mfa_for?(name, permission_level)
    case permission_level
    when :check
      fetch(name).check_requires_mfa
    when :get
      fetch(name).get_requires_mfa
    when :set
      fetch(name).set_requires_mfa
    else
      raise UnknownPermission, permission_level
    end
  end

  def fetch(name)
    attributes.fetch(name.to_sym)
  end
end
