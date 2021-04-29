class AttributesController < ApplicationController
  before_action :require_govuk_account_session!

  def show
    remote_attributes = get_attributes_from_params(
      params.fetch(:attributes),
      permission_level: :get,
    )

    values = @govuk_account_session.get_remote_attributes(remote_attributes)

    render json: {
      govuk_account_session: @govuk_account_session.serialise,
      values: values.compact,
    }
  rescue OidcClient::OAuthFailure
    head :unauthorized
  end

  def update
    remote_attributes = get_attributes_from_params(
      params.fetch(:attributes).permit!.to_h,
      permission_level: :set,
      is_hash: true,
    )

    @govuk_account_session.set_remote_attributes(remote_attributes)

    render json: {
      govuk_account_session: @govuk_account_session.serialise,
    }
  rescue OidcClient::OAuthFailure
    head :unauthorized
  end

private

  def get_attributes_from_params(attributes, permission_level:, is_hash: false)
    attribute_names = is_hash ? attributes.keys : attributes

    unknown_attributes = attribute_names.reject { |name| user_attributes.defined? name }
    raise ApiError::UnknownAttributeNames, { attributes: unknown_attributes } if unknown_attributes.any?

    if Rails.application.config.feature_flag_enforce_levels_of_authentication
      forbidden_attributes = attribute_names.reject { |name| user_attributes.has_permission_for? name, permission_level, @govuk_account_session }
      if forbidden_attributes.any?
        needed_level_of_authentication = forbidden_attributes.map { |name| user_attributes.level_of_authentication_for name, permission_level }.max
        raise ApiError::LevelOfAuthenticationTooLow, { attributes: forbidden_attributes, needed_level_of_authentication: needed_level_of_authentication }
      end
    end

    local_attributes = attributes.select { |name| user_attributes.stored_locally? name }
    remote_attributes = attributes.reject { |name| user_attributes.stored_locally? name }

    raise NotImplementedError if local_attributes.any?

    remote_attributes
  end

  def user_attributes
    @user_attributes ||= UserAttributes.new
  end
end
