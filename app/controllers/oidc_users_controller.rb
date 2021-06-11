class OidcUsersController < ApplicationController
  OIDC_USER_ATTRIBUTES = %i[email email_verified].freeze

  def update
    user = OidcUser.find_or_create_by!(sub: params.fetch(:subject_identifier))
    user.set_local_attributes(params.permit(OIDC_USER_ATTRIBUTES).to_h)
    attributes = user.get_local_attributes(OIDC_USER_ATTRIBUTES)

    if attributes["email"] && !attributes["email_verified"].nil?
      user.email_subscriptions.each do |email_subscription|
        email_subscription.reactivate_if_confirmed!(
          attributes["email"],
          attributes["email_verified"],
        )
      end
    end

    render json: attributes.merge(sub: user.sub)
  end

private

  def authorise_sso_user!
    authorise_user!("update_protected_attributes")
  end
end
