class TransitionCheckerEmailSubscriptionController < ApplicationController
  include AuthenticatedApiConcern

  def show
    check_permission! :check

    subscription = @govuk_account_session.get_transition_checker_email_subscription

    render_api_response has_subscription: subscription.present?
  end

  def update
    check_permission! :set

    @govuk_account_session.set_transition_checker_email_subscription(params.require(:slug))
    render_api_response
  end

private

  def check_permission!(permission_level)
    return if user_attributes.has_permission_for? "transition_checker_state", permission_level, @govuk_account_session

    needed_level_of_authentication = user_attributes.level_of_authentication_for "transition_checker_state", permission_level
    raise ApiError::LevelOfAuthenticationTooLow, { attributes: %w[transition_checker_state], needed_level_of_authentication: needed_level_of_authentication }
  end

  def user_attributes
    @user_attributes ||= UserAttributes.new
  end
end
