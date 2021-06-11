class EmailSubscription < ApplicationRecord
  belongs_to :oidc_user

  validates :name, presence: true
  validates :topic_slug, presence: true

  def to_hash
    {
      "name" => name,
      "topic_slug" => topic_slug,
      "email_alert_api_subscription_id" => email_alert_api_subscription_id,
    }.compact
  end
end
