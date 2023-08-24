class Internal::OidcUsersController < InternalController
  OIDC_USER_ATTRIBUTES = %w[email email_verified].freeze

  def update
    user = OidcUser.find_or_create_by_sub!(
      params.fetch(:subject_identifier),
      legacy_sub: params[:legacy_sub],
    )

    email_changed = params.key?(:email) && (params[:email] != user.email)
    email_verified_changed = params.key?(:email_verified) && params[:email_verified] != user.email_verified

    capture_sensitive_exceptions(user) do
      user.update!(params.permit(OIDC_USER_ATTRIBUTES).to_h.compact)
      user.reload
    end

    if (email_changed || email_verified_changed) && user.email && user.email_verified
      update_email_alert_api_address(user)
    end

    render json: user.get_attributes_by_name(OIDC_USER_ATTRIBUTES).merge(sub: user.sub)
  end

  def destroy
    user = OidcUser.find_by_sub!(
      params.fetch(:subject_identifier),
      legacy_sub: params[:legacy_sub],
    )

    end_email_alert_api_subscriptions(user)
    invalidate_logout_notice(params.fetch(:subject_identifier))

    user.destroy!

    head :no_content
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

private

  def authorise_sso_user!
    authorise_user!("update_protected_attributes")
  end

  def update_email_alert_api_address(user)
    GdsApi.email_alert_api.change_subscriber(
      id: email_alert_api_subscriber_id(user),
      new_address: user.email,
      on_conflict: "merge",
    )
  rescue GdsApi::HTTPNotFound
    # No linked email-alert-api account, nothing to do
    nil
  end

  def end_email_alert_api_subscriptions(user)
    GdsApi.email_alert_api.unsubscribe_subscriber(
      email_alert_api_subscriber_id(user),
    )
  rescue GdsApi::HTTPNotFound
    # No linked email-alert-api account, nothing to do
    nil
  end

  def email_alert_api_subscriber_id(user)
    GdsApi.email_alert_api
      .find_subscriber_by_govuk_account(govuk_account_id: user.id)
      .dig("subscriber", "id")
  end
end
