class TransitionCheckerEmailSubscriptionController < ApplicationController
  include AuthenticatedApiConcern

  def show
    check_permission! :check

    render_api_response has_subscription: @govuk_account_session.has_email_subscription?
  end

  def update
    check_permission! :set

    @govuk_account_session.set_email_subscription(params.require(:slug))
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
