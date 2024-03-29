require "gds_api/email_alert_api"

class Personalisation::CheckEmailSubscriptionController < PersonalisationController
  before_action do
    @base_path = params[:base_path]
    @topic_slug = params[:topic_slug]

    head :unprocessable_entity if @base_path && @topic_slug
    head :unprocessable_entity unless @base_path || @topic_slug
  end

  def show
    sub = GdsApi.email_alert_api.find_subscriber_by_govuk_account(govuk_account_id: @govuk_account_session.user.id).to_hash.dig("subscriber", "id")
    subscriptions = GdsApi.email_alert_api.get_subscriptions(id: sub).to_hash.fetch("subscriptions")

    is_active =
      if @base_path
        subscriptions.find { |subscription| subscription.dig("subscriber_list", "url") == @base_path }.present?
      else
        subscriptions.find { |subscription| subscription.dig("subscriber_list", "slug") == @topic_slug }.present?
      end

    render json: response_json(active: is_active)
  rescue GdsApi::HTTPNotFound
    render json: response_json
  end

private

  def response_json(active: false)
    {
      base_path: @base_path,
      topic_slug: @topic_slug,
      active:,
    }.compact
  end
end
