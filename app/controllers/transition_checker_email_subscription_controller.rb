class TransitionCheckerEmailSubscriptionController < ApplicationController
  before_action :fetch_govuk_account_session

  def show
    oauth_response = OidcClient.new.has_email_subscription(
      access_token: @govuk_account_session.access_token,
      refresh_token: @govuk_account_session.refresh_token,
    )
    @govuk_account_session.access_token = oauth_response[:access_token]
    @govuk_account_session.refresh_token = oauth_response[:refresh_token]

    render json: {
      govuk_account_session: @govuk_account_session.serialise,
      has_subscription: oauth_response[:result],
    }
  rescue OidcClient::OAuthFailure
    head :unauthorized
  end

  def update
    oauth_response = OidcClient.new.update_email_subscription(
      slug: params.require(:slug),
      access_token: @govuk_account_session.access_token,
      refresh_token: @govuk_account_session.refresh_token,
    )
    @govuk_account_session.access_token = oauth_response[:access_token]
    @govuk_account_session.refresh_token = oauth_response[:refresh_token]

    render json: {
      govuk_account_session: @govuk_account_session.serialise,
    }
  rescue OidcClient::OAuthFailure
    head :unauthorized
  end
end
