class EmailSubscription < ApplicationRecord
  class SubscriberListNotFound < StandardError; end

  belongs_to :oidc_user

  validates :name, presence: true
  validates :topic_slug, presence: true

  before_destroy :deactivate!

  def to_hash
    {
      "name" => name,
      "topic_slug" => topic_slug,
      "email_alert_api_subscription_id" => email_alert_api_subscription_id,
    }.compact
  end

  def activated?
    email_alert_api_subscription_id.present?
  end

  def check_if_still_active!
    GdsApi
      .email_alert_api.get_subscription(email_alert_api_subscription_id)
      .dig("subscription", "ended_reason")
      .blank?
  rescue GdsApi::HTTPGone, GdsApi::HTTPNotFound
    false
  end

  def reactivate_if_confirmed!
    deactivate!

    return unless oidc_user.email
    return unless oidc_user.email_verified

    subscriber_list =
      begin
        GdsApi.email_alert_api.get_subscriber_list(slug: topic_slug)
      rescue GdsApi::HTTPNotFound
        raise SubscriberListNotFound
      end

    subscription = GdsApi.email_alert_api.subscribe(
      subscriber_list_id: subscriber_list.dig("subscriber_list", "id"),
      address: oidc_user.email,
      frequency: "daily",
      skip_confirmation_email: true,
    )

    update!(email_alert_api_subscription_id: subscription.dig("subscription", "id"))
  end

  def deactivate!
    return unless email_alert_api_subscription_id

    GdsApi.email_alert_api.unsubscribe(email_alert_api_subscription_id)
  rescue GdsApi::HTTPGone, GdsApi::HTTPNotFound
    # this can happen if the subscription has been deactivated by the
    # user through email-alert-frontend
  ensure
    update!(email_alert_api_subscription_id: nil)
  end
end
