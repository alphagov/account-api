class Internal::AttributesController < InternalController
  include AuthenticatedApiConcern

  def show
    validate_attributes!(attributes, :get)

    render_api_response values: @govuk_account_session.get_attributes(attributes)
  end

  def update
    @attributes = attributes.permit!.to_h
    validate_attributes!(attributes.keys, :set)

    @govuk_account_session.set_attributes(attributes)
    render_api_response
  end

private

  def attributes
    @attributes ||= params.fetch(:attributes)
  end

  def validate_attributes!(attribute_names, permission_level)
    unknown_attributes = attribute_names.reject { |name| user_attributes.defined? name }
    raise ApiError::UnknownAttributeNames.new(attributes: unknown_attributes) if unknown_attributes.any?

    if permission_level == :set
      unwritable_attributes = attribute_names.reject { |name| user_attributes.is_writable? name }
      raise ApiError::UnwritableAttributes.new(attributes: unwritable_attributes) if unwritable_attributes.any?
    end

    attributes_needing_mfa = attribute_names.reject { |name| user_attributes.has_permission_for? name, permission_level, @govuk_account_session }
    if attributes_needing_mfa.any?
      raise ApiError::MfaRequired.new(attributes: attributes_needing_mfa)
    end
  end

  def user_attributes
    @user_attributes ||= UserAttributes.new
  end
end
