class ApplicationController < ActionController::API
  include GDS::SSO::ControllerMethods

  before_action :authorise

  def to_account_session(access_token, refresh_token)
    "#{Base64.urlsafe_encode64(access_token)}.#{Base64.urlsafe_encode64(refresh_token)}"
  end

protected

  def authorise
    authorise_user!("internal_app")
  end
end
