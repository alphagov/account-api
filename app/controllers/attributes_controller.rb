class AttributesController < ApplicationController
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
    raise ApiError::UnknownAttributeNames, { attributes: unknown_attributes } if unknown_attributes.any?

    if Rails.application.config.feature_flag_enforce_levels_of_authentication
      forbidden_attributes = attribute_names.reject { |name| user_attributes.has_permission_for? name, permission_level, @govuk_account_session }
      if forbidden_attributes.any?
        needed_level_of_authentication = forbidden_attributes.map { |name| user_attributes.level_of_authentication_for name, permission_level }.max
        raise ApiError::LevelOfAuthenticationTooLow, { attributes: forbidden_attributes, needed_level_of_authentication: needed_level_of_authentication }
      end
    end
  end

  def user_attributes
    @user_attributes ||= UserAttributes.new
  end
end
