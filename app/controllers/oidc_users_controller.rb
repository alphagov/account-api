class OidcUsersController < ApplicationController
  OIDC_USER_ATTRIBUTES = %w[email email_verified has_unconfirmed_email].freeze

  def update
    user = OidcUser.find_or_create_by_sub!(params.fetch(:subject_identifier))
    user.set_local_attributes(params.permit(OIDC_USER_ATTRIBUTES).to_h)
    attributes = user.get_local_attributes(OIDC_USER_ATTRIBUTES)

    if attributes["email"] && attributes["email_verified"]
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
          new_address: attributes["email"],
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

    render json: attributes.merge(sub: user.sub)
  end

  def destroy
    user = OidcUser.find_by!(sub: params.fetch(:subject_identifier))
    user.destroy!
    head :no_content and return
  rescue ActiveRecord::RecordNotFound
    head :not_found and return
  end

private

  def authorise_sso_user!
    authorise_user!("update_protected_attributes")
  end
end
