class UserAttributes
  attr_reader :attributes

  class UnknownPermission < StandardError; end

  def initialize(attributes = nil)
    @attributes = (attributes || UserAttributes.load_config_file).transform_values do |config|
      AttributeDefinition.new(
        type: config["type"],
        writable: config.fetch("writable", true),
        level_of_auth_check: config.dig("permissions", "check") || 0,
        level_of_auth_get: config.dig("permissions", "get") || 0,
        level_of_auth_set: config.dig("permissions", "set") || 0,
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
    user_session.level_of_authentication_as_integer >= level_of_authentication_for(name, permission_level)
  end

  def level_of_authentication_for(name, permission_level)
    case permission_level
    when :check
      attributes.fetch(name).level_of_auth_check
    when :get
      attributes.fetch(name).level_of_auth_get
    when :set
      attributes.fetch(name).level_of_auth_set
    else
      raise UnknownPermission, permission_level
    end
  end

  def self.load_config_file
    YAML.safe_load(File.read(Rails.root.join("config/user_attributes.yml"))).with_indifferent_access
  end
end
