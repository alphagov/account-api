require "gds_api/email_alert_api"

class CheckEmailSubscriptionController < ApplicationController
  include GovukPersonalisation::ControllerConcern

  skip_before_action :authorise_sso_user!

  before_action do
    @govuk_account_session = AccountSession.deserialise(
      encoded_session: @account_session_header,
      session_secret: Rails.application.secrets.session_secret,
    )

    unless @govuk_account_session
      logout_and_401
    end
  end

  rescue_from OidcClient::OAuthFailure do
    logout_and_401
  end

  def show
    sub = GdsApi.email_alert_api.find_subscriber_by_govuk_account(govuk_account_id: @govuk_account_session.user.id).to_hash.dig("subscriber", "id")
    subscriptions = GdsApi.email_alert_api.get_subscriptions(id: sub).to_hash.fetch("subscriptions")
    is_active = subscriptions.find { |subscription| subscription.dig("subscriber_list", "slug") == params["topic_slug"] }.present?

    render json: response_json(active: is_active)
  rescue GdsApi::HTTPNotFound
    render json: response_json
  end

private

  def logout_and_401
    logout!
    head :unauthorized
  end

  def response_json(active: false)
    {
      topic_slug: params[:topic_slug],
      active: active,
    }
  end
end
