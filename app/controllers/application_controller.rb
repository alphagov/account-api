class ApplicationController < ActionController::API
  include GDS::SSO::ControllerMethods

  before_action do
    authorise_user!("internal_app")
  end

  rescue_from ApiError::Base do |error|
    render status: error.status_code, json: {
      type: error.type,
      title: error.title,
      detail: error.detail,
    }.merge(error.extra_detail)
  end
end
