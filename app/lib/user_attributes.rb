class UserAttributes
  CONFIG_KEYS = %w[type writable permissions].freeze
  PERMISSION_KEYS = %w[check get set].freeze

  attr_reader :attributes

  def initialize(attributes = nil)
    @attributes = (attributes || UserAttributes.load_config_file).transform_values do |config|
      config ||= {}
      config["writable"] = true unless config.key? "writable"
      config
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
    attributes.fetch(name)[:permissions].fetch(permission_level)
  end

  def self.validate(attributes)
    new(attributes).errors
  end

  def errors
    attributes.each_with_object({}) do |(name, config), errors|
      missing_keys = CONFIG_KEYS - config.keys
      unknown_keys = config.keys - CONFIG_KEYS
      invalid_keys = []

      invalid_keys << "type" if config["type"] && !config["type"].in?(%w[local remote cached])

      permissions = config["permissions"]
      if permissions
        permissions_keys = config["writable"] ? PERMISSION_KEYS : PERMISSION_KEYS - %w[set]

        missing_keys.concat((permissions_keys - permissions.keys).map { |key| "permissions.#{key}" })
        unknown_keys.concat((permissions.keys - permissions_keys).map { |key| "permissions.#{key}" })

        non_integer_values = permissions.keys.reject { |key| permissions[key].is_a? Integer }.map { |key| "permissions.#{key}" }
        if non_integer_values.any?
          invalid_keys.concat non_integer_values
        else
          if permissions["check"] && permissions["get"] && permissions["check"] > permissions["get"]
            invalid_keys << "permissions.check"
          end
          if permissions["get"] && permissions["set"] && permissions["get"] > permissions["set"]
            invalid_keys << "permissions.get"
          end
        end
      end

      this_errors = {
        missing_keys: missing_keys.any? ? missing_keys : nil,
        unknown_keys: unknown_keys.any? ? unknown_keys : nil,
        invalid_keys: invalid_keys.any? ? invalid_keys : nil,
      }.compact

      errors[name] = this_errors if this_errors.any?
    end
  end

  def self.load_config_file
    YAML.safe_load(File.read(Rails.root.join("config/user_attributes.yml"))).with_indifferent_access
  end
end
