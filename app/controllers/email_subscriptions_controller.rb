class EmailSubscriptionsController < ApplicationController
  include AuthenticatedApiConcern

  before_action :check_subscription_exists, only: %i[show destroy]

  def show
    if email_subscription.activated? && !email_subscription.check_if_still_active!
      email_subscription.destroy!
      head :not_found and return
    end

    render_api_response(email_subscription: email_subscription.to_hash)
  end

  def update
    @govuk_account_session.get_attributes(%w[email email_verified])

    email_subscription = EmailSubscription.transaction do
      EmailSubscription
        .create_with(topic_slug: params.fetch(:topic_slug))
        .find_or_create_by!(
          oidc_user_id: @govuk_account_session.user.id,
          name: params.fetch(:subscription_name),
        ).tap { |subscription| subscription.update!(topic_slug: params.fetch(:topic_slug)) }
    end

    email_subscription.reactivate_if_confirmed!

    render_api_response(email_subscription: email_subscription.to_hash)
  end

  def destroy
    email_subscription.destroy!
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
    head :not_found unless email_subscription
  end
end
