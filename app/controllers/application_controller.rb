class ApplicationController < ActionController::API
  include GDS::SSO::ControllerMethods

  before_action :authorise

protected

  def authorise
    authorise_user!("internal_app")
  end
end
