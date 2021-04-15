class AttributesController < ApplicationController
  before_action :fetch_govuk_account_session

  def show
    attribute_names = params.fetch(:attributes)

    return unless validate_attributes(attribute_names)

    access_token = @govuk_account_session[:access_token]
    refresh_token = @govuk_account_session[:refresh_token]

    values = attribute_names.each_with_object({}) do |name, values_hash|
      if user_attributes.stored_locally? name
        raise NotImplementedError
      else
        oauth_response = OidcClient.new.get_attribute(
          attribute: name,
          access_token: access_token,
          refresh_token: refresh_token,
        )
        access_token = oauth_response[:access_token]
        refresh_token = oauth_response[:refresh_token]
        values_hash[name] = oauth_response[:result]
      end
    end

    render json: {
      govuk_account_session: to_account_session(
        access_token: access_token,
        refresh_token: refresh_token,
        level_of_authentication: @govuk_account_session[:level_of_authentication],
      ),
      values: values.compact,
    }
  rescue OidcClient::OAuthFailure
    head :unauthorized
  end

  def update
    attributes = params.fetch(:attributes).permit!.to_h

    return unless validate_attributes(attributes.keys)

    access_token = @govuk_account_session[:access_token]
    refresh_token = @govuk_account_session[:refresh_token]

    local_attributes = attributes.select { |name| user_attributes.stored_locally? name }
    remote_attributes = attributes.reject { |name| user_attributes.stored_locally? name }

    if local_attributes.any?
      raise NotImplementedError
    end

    if remote_attributes.any?
      oauth_response = OidcClient.new.bulk_set_attributes(
        attributes: remote_attributes,
        access_token: access_token,
        refresh_token: refresh_token,
      )
      access_token = oauth_response[:access_token]
      refresh_token = oauth_response[:refresh_token]
    end

    render json: {
      govuk_account_session: to_account_session(
        access_token: access_token,
        refresh_token: refresh_token,
        level_of_authentication: @govuk_account_session[:level_of_authentication],
      ),
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
