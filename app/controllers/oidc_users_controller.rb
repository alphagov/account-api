class OidcUsersController < ApplicationController
  include DigitalIdentityHelper

  OIDC_USER_ATTRIBUTES = %w[email email_verified has_unconfirmed_email].freeze

  def update
    user = OidcUser.find_or_create_by_sub!(
      params.fetch(:subject_identifier),
      legacy_sub: using_digital_identity? ? params[:legacy_sub] : nil,
    )

    user.update!(params.permit(OIDC_USER_ATTRIBUTES).to_h)
    user.reload

    if user.email && user.email_verified
      begin
        # if the user has linked their notifications account to their
        # GOV.UK account we don't need to update their
        # `user.email_subscriptions`, because we can update the
        # subscriber directly.
        subscriber_id = GdsApi.email_alert_api
          .find_subscriber_by_govuk_account(govuk_account_id: user.id)
          .dig("subscriber", "id")
        GdsApi.email_alert_api.change_subscriber(
          id: subscriber_id,
          new_address: user.email,
          on_conflict: "merge",
        )
      rescue GdsApi::HTTPNotFound
        # but for users who haven't linked their notifications account
        # to their GOV.UK account, we do need to update any
        # account-linked subscriptions they have (eg, brexit checker
        # users who haven't touched notifications since registering
        # through the checker).
        #
        # this branch can be removed once we have no GOV.UK accounts
        # which have subscriptions but are *not* linked to the
        # corresponding notifications account.
        user.email_subscriptions.each(&:reactivate_if_confirmed!)
      end
    end

    render json: user.get_attributes_by_name(OIDC_USER_ATTRIBUTES).merge(sub: user.sub)
  end

  def destroy
    OidcUser.find_by_sub!(
      params.fetch(:subject_identifier),
      legacy_sub: using_digital_identity? ? params[:legacy_sub] : nil,
    ).destroy!
    head :no_content
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

private

  def authorise_sso_user!
    authorise_user!("update_protected_attributes")
  end
end
