class EmailSubscriptionsController < ApplicationController
  include AuthenticatedApiConcern

  TRANSITION_CHECKER_SUBSCRIPTION_NAME = "transition-checker-results".freeze

  before_action :check_subscription_exists, only: %i[show destroy]

  # the transition checker-specific stuff in here is temporary: after
  # removing the JWT flow, we will start saving transition checker
  # data to the local database and only calling the account-manager if
  # it's not present locally; we'll also need to do a bulk import of
  # data from users who don't log in for a while.
  #
  # the point of adding this logic to the endpoints now, before
  # implementing the data import, is so that we can update the
  # transition checker to use the new endpoints sooner rather than
  # later.

  def show
    if is_transition_checker_subscription?
      legacy_subscription = @govuk_account_session.get_transition_checker_email_subscription
      if legacy_subscription
        render_api_response(email_subscription:
          {
            "name" => TRANSITION_CHECKER_SUBSCRIPTION_NAME,
            "topic_slug" => legacy_subscription["topic_slug"],
            "email_alert_api_subscription_id" => legacy_subscription["subscription_id"],
          }.compact)
      else
        head :not_found
      end

      return
    end

    if email_subscription.email_alert_api_subscription_id
      begin
        state = GdsApi.email_alert_api.get_subscription(email_subscription.email_alert_api_subscription_id)
        if state.to_hash.dig("subscription", "ended_reason")
          email_subscription.destroy!
          head :not_found and return
        end
      rescue GdsApi::HTTPGone, GdsApi::HTTPNotFound
        email_subscription.destroy!
        head :not_found and return
      end
    end

    render_api_response(email_subscription: email_subscription.to_hash)
  end

  def update
    if is_transition_checker_subscription?
      legacy_subscription = @govuk_account_session.set_transition_checker_email_subscription(params.require(:topic_slug))
      render_api_response(email_subscription:
        {
          "name" => TRANSITION_CHECKER_SUBSCRIPTION_NAME,
          "topic_slug" => legacy_subscription["topic_slug"],
          "email_alert_api_subscription_id" => legacy_subscription["subscription_id"],
        }.compact)

      return
    end

    attributes = @govuk_account_session.get_attributes(%w[email email_verified])

    email_subscription = EmailSubscription.transaction do
      EmailSubscription
        .create_with(topic_slug: params.fetch(:topic_slug))
        .find_or_create_by!(
          oidc_user_id: @govuk_account_session.user.id,
          name: params.fetch(:subscription_name),
        ).tap { |subscription| subscription.update!(topic_slug: params.fetch(:topic_slug)) }
    end

    email_subscription.reactivate_if_confirmed!(
      attributes["email"],
      attributes["email_verified"],
    )

    render_api_response(email_subscription: email_subscription.to_hash)
  end

  def destroy
    email_subscription.destroy! unless is_transition_checker_subscription?
    head :no_content
  end

private

  def email_subscription
    @email_subscription ||= EmailSubscription.find_by(
      oidc_user: @govuk_account_session.user,
      name: params.fetch(:subscription_name),
    )
  end

  def check_subscription_exists
    return if is_transition_checker_subscription?

    head :not_found unless email_subscription
  end

  def is_transition_checker_subscription?
    params.fetch(:subscription_name) == TRANSITION_CHECKER_SUBSCRIPTION_NAME
  end
end
