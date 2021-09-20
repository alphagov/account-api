class UserAttributes
  attr_reader :attributes

  class UnknownPermission < StandardError; end

  def initialize(attributes = nil)
    @attributes = (attributes || UserAttributes.load_config_file).transform_values do |config|
      AttributeDefinition.new(
        type: config["type"],
        writable: config.fetch("writable", true),
        check_requires_mfa: config.fetch("check_requires_mfa", false),
        get_requires_mfa: config.fetch("get_requires_mfa", false),
        set_requires_mfa: config.fetch("set_requires_mfa", false),
      )
    end
  end

  def defined?(name)
    attributes.key? name
  end

  def type(name)
    attributes.fetch(name)[:type]
  end

  def is_writable?(name)
    attributes.fetch(name)[:writable]
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
      attributes.fetch(name).check_requires_mfa
    when :get
      attributes.fetch(name).get_requires_mfa
    when :set
      attributes.fetch(name).set_requires_mfa
    else
      raise UnknownPermission, permission_level
    end
  end

  def self.load_config_file
    YAML.safe_load(File.read(Rails.root.join("config/user_attributes.yml"))).with_indifferent_access
  end
end
