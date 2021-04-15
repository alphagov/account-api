class UserAttributes
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
end
