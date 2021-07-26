class EmailSubscription < ApplicationRecord
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
      .to_hash
      .dig("subscription", "ended_reason")
      .blank?
  rescue GdsApi::HTTPGone, GdsApi::HTTPNotFound
    false
  end

  def reactivate_if_confirmed!(email, email_verified)
    deactivate!

    return unless email_verified

    subscriber_list = GdsApi.email_alert_api.get_subscriber_list(
      slug: topic_slug,
    )

    subscription = GdsApi.email_alert_api.subscribe(
      subscriber_list_id: subscriber_list.to_hash.dig("subscriber_list", "id"),
      address: email,
      frequency: "daily",
      skip_confirmation_email: true,
    )

    update!(email_alert_api_subscription_id: subscription.to_hash.dig("subscription", "id"))
  end

  def deactivate!
    return unless email_alert_api_subscription_id

    GdsApi.email_alert_api.unsubscribe(email_alert_api_subscription_id)
    update!(email_alert_api_subscription_id: nil)
  rescue GdsApi::HTTPGone, GdsApi::HTTPNotFound
    # this can happen if the subscription has been deactivated by the
    # user through email-alert-frontend
    update!(email_alert_api_subscription_id: nil)
  end
end
