class EmailSubscriptionsController < ApplicationController
  include AuthenticatedApiConcern

  TRANSITION_CHECKER_SUBSCRIPTION_NAME = "transition-checker-results".freeze

  before_action :migrate_transition_checker_subscription
  before_action :check_subscription_exists, only: %i[show destroy]

  def show
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
    email_subscription.destroy!
    head :no_content
  end

private

  # remove this after we've done a bulk import of older subscriptions
  def migrate_transition_checker_subscription
    return unless params.fetch(:subscription_name) == TRANSITION_CHECKER_SUBSCRIPTION_NAME
    return if email_subscription

    legacy_subscription = @govuk_account_session.get_transition_checker_email_subscription
    return unless legacy_subscription

    @email_subscription = EmailSubscription.create!(
      oidc_user: @govuk_account_session.user,
      name: TRANSITION_CHECKER_SUBSCRIPTION_NAME,
      topic_slug: legacy_subscription["topic_slug"],
      email_alert_api_subscription_id: legacy_subscription["subscription_id"],
    )

    @govuk_account_session.migrate_transition_checker_email_subscription
  end

  def email_subscription
    @email_subscription ||= EmailSubscription.find_by(
      oidc_user: @govuk_account_session.user,
      name: params.fetch(:subscription_name),
    )
  end

  def check_subscription_exists
    head :not_found unless email_subscription
  end
end
