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
      .dig("subscription", "ended_reason")
      .blank?
  rescue GdsApi::HTTPGone, GdsApi::HTTPNotFound
    false
  end

  def reactivate_if_confirmed!
    deactivate!

    attributes = oidc_user.get_local_attributes(%w[email email_verified])
    return unless attributes["email_verified"]

    subscriber_list = GdsApi.email_alert_api.get_subscriber_list(
      slug: topic_slug,
    )

    subscription = GdsApi.email_alert_api.subscribe(
      subscriber_list_id: subscriber_list.dig("subscriber_list", "id"),
      address: attributes["email"],
      frequency: "daily",
      skip_confirmation_email: true,
    )

    update!(email_alert_api_subscription_id: subscription.dig("subscription", "id"))

    send_transition_checker_onboarding_email!
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

  def send_transition_checker_onboarding_email!
    return unless email_alert_api_subscription_id
    return unless name == "transition-checker-results"
    return if oidc_user.has_received_transition_checker_onboarding_email

    SendEmailWorker.perform_async(
      oidc_user.get_local_attributes(%w[email])["email"],
      I18n.t("emails.onboarding.transition_checker.subject"),
      I18n.t("emails.onboarding.transition_checker.body", sign_in_link: "#{Plek.find('account-manager')}/sign-in"),
    )

    oidc_user.update!(has_received_transition_checker_onboarding_email: true)
  end
end
