class TransitionCheckerEmailSubscriptionController < ApplicationController
  include AuthenticatedApiConcern

  def show
    render_api_response has_subscription: @govuk_account_session.has_email_subscription?
  end

  def update
    @govuk_account_session.set_email_subscription(params.require(:slug))
    render_api_response
  end
end
