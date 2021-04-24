class TransitionCheckerEmailSubscriptionController < ApplicationController
  before_action :fetch_govuk_account_session

  def show
    has_subscription = @govuk_account_session.has_email_subscription?

    render json: {
      govuk_account_session: @govuk_account_session.serialise,
      has_subscription: has_subscription,
    }
  rescue OidcClient::OAuthFailure
    head :unauthorized
  end

  def update
    @govuk_account_session.set_email_subscription(params.require(:slug))

    render json: {
      govuk_account_session: @govuk_account_session.serialise,
    }
  rescue OidcClient::OAuthFailure
    head :unauthorized
  end
end
