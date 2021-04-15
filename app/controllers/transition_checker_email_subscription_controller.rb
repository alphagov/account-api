class TransitionCheckerEmailSubscriptionController < ApplicationController
  before_action :fetch_govuk_account_session

  def show
    oauth_response = OidcClient.new.has_email_subscription(
      access_token: @govuk_account_session[:access_token],
      refresh_token: @govuk_account_session[:refresh_token],
    )

    render json: {
      govuk_account_session: to_account_session(
        access_token: oauth_response[:access_token],
        refresh_token: oauth_response[:refresh_token],
        level_of_authentication: @govuk_account_session[:level_of_authentication],
      ),
      has_subscription: oauth_response[:result],
    }
  rescue OidcClient::OAuthFailure
    head :unauthorized
  end

  def update
    oauth_response = OidcClient.new.update_email_subscription(
      slug: params.require(:slug),
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
