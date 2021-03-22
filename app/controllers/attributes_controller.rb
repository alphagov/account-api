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
      govuk_account_session: to_account_session(access_token, refresh_token),
      values: values.compact,
    }
  rescue OidcClient::OAuthFailure
    head :unauthorized
  end

  def update
    attributes = params.fetch(:attributes).permit!.to_h

    already_encoded = attributes.values.all? { |v| is_json_encoded v }

    oauth_response = OidcClient.new.bulk_set_attributes(
      attributes: attributes,
      already_encoded: already_encoded,
      access_token: @govuk_account_session[:access_token],
      refresh_token: @govuk_account_session[:refresh_token],
    )

    render json: {
      govuk_account_session: to_account_session(oauth_response[:access_token], oauth_response[:refresh_token]),
    }
  rescue OidcClient::OAuthFailure
    head :unauthorized
  end

protected

  def is_json_encoded(value)
    return false unless value.is_a? String

    JSON.parse(value)
    true
  rescue JSON::ParserError
    false
  end
end
