class OidcUsersController < ApplicationController
  OIDC_USER_ATTRIBUTES = %i[email email_verified].freeze

  def update
    user = OidcUser.find_or_create_by!(sub: params.fetch(:subject_identifier))
    user.set_local_attributes(params.permit(OIDC_USER_ATTRIBUTES).to_h)
    render json: user.get_local_attributes(OIDC_USER_ATTRIBUTES).merge(sub: user.sub)
  end

private

  def authorise_sso_user!
    authorise_user!("update_protected_attributes")
  end
end
