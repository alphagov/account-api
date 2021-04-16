class UserAttributes
  CONFIG_KEYS = %w[is_stored_locally].freeze

  attr_reader :attributes

  def initialize
    @attributes = YAML.safe_load(File.read(Rails.root.join("config/user_attributes.yml"))).with_indifferent_access

    if Rails.env.test?
      test_attributes = YAML.safe_load(File.read(Rails.root.join("spec/fixtures/user_attributes.yml"))).with_indifferent_access
      @attributes.merge!(test_attributes)
    end
  end

  def defined?(name)
    attributes.key? name
  end

  def stored_locally?(name)
    attributes.fetch(name)[:is_stored_locally]
  end

  def errors
    attributes.each_with_object({}) do |(name, config), errors|
      config ||= {}

      missing_keys = CONFIG_KEYS.reject { |key| config.keys.include? key }
      unknown_keys = config.keys.reject { |key| CONFIG_KEYS.include? key }

      invalid_keys = []
      unless config["is_stored_locally"].in?([nil, false, true])
        invalid_keys << :is_stored_locally
      end

      this_errors = {
        missing_keys: missing_keys.any? ? missing_keys : nil,
        unknown_keys: unknown_keys.any? ? unknown_keys : nil,
        invalid_keys: invalid_keys.any? ? invalid_keys : nil,
      }.compact

      errors[name] = this_errors if this_errors.any?
    end
  end
end
