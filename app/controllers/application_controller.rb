class ApplicationController < ActionController::API
  include GDS::SSO::ControllerMethods

  before_action :authorise!

  rescue_from ApiError::Base, with: :json_api_error

private

  def authorise!
    authorise_user!("internal_app")
  end

  def json_api_error(error)
    render status: error.status_code, json: {
      type: error.type,
      title: error.title,
      detail: error.detail,
    }.merge(error.extra_detail)
  end
end
