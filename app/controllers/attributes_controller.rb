class AttributesController < ApplicationController
  before_action :require_govuk_account_session!

  def show
    attribute_names = params.fetch(:attributes)

    return unless validate_attributes(attribute_names)

    local_attributes = attribute_names.select { |name| user_attributes.stored_locally? name }
    remote_attributes = attribute_names.reject { |name| user_attributes.stored_locally? name }

    raise NotImplementedError if local_attributes.any?

    values = @govuk_account_session.get_remote_attributes(remote_attributes)

    render json: {
      govuk_account_session: @govuk_account_session.serialise,
      values: values.compact,
    }
  rescue OidcClient::OAuthFailure
    head :unauthorized
  end

  def update
    attributes = params.fetch(:attributes).permit!.to_h

    return unless validate_attributes(attributes.keys)

    local_attributes = attributes.select { |name| user_attributes.stored_locally? name }
    remote_attributes = attributes.reject { |name| user_attributes.stored_locally? name }

    raise NotImplementedError if local_attributes.any?

    @govuk_account_session.set_remote_attributes(remote_attributes)

    render json: {
      govuk_account_session: @govuk_account_session.serialise,
    }
  rescue OidcClient::OAuthFailure
    head :unauthorized
  end

private

  def validate_attributes(names)
    undefined = names.reject { |n| user_attributes.defined? n }
    if undefined.any?
      render status: :unprocessable_entity, json:
        {
          type: I18n.t("errors.unknown_attribute_names.type"),
          title: I18n.t("errors.unknown_attribute_names.title"),
          detail: I18n.t("errors.unknown_attribute_names.detail", attribute_names: undefined.join(", ")),
          attributes: undefined,
        }
      return false
    end

    true
  end

  def user_attributes
    @user_attributes ||= UserAttributes.new
  end
end
