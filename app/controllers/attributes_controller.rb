class AttributesController < ApplicationController
  before_action :fetch_govuk_account_session

  def show
    attribute_names = params.fetch(:attributes)

    access_token = @govuk_account_session[:access_token]
    refresh_token = @govuk_account_session[:refresh_token]

    values = attribute_names.each_with_object({}) do |name, values_hash|
      oauth_response = OidcClient.new.get_attribute(
        attribute: name,
        access_token: access_token,
        refresh_token: refresh_token,
      )
      access_token = oauth_response[:access_token]
      refresh_token = oauth_response[:refresh_token]
      values_hash[name] = oauth_response[:result]
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

    oauth_response = OidcClient.new.bulk_set_attributes(
      attributes: attributes,
      access_token: @govuk_account_session[:access_token],
      refresh_token: @govuk_account_session[:refresh_token],
    )

    render json: {
      govuk_account_session: to_account_session(
        access_token: oauth_response[:access_token],
        refresh_token: oauth_response[:refresh_token],
        level_of_authentication: @govuk_account_session[:level_of_authentication],
      ),
    }
  rescue OidcClient::OAuthFailure
    head :unauthorized
  end
end
