class ApplicationController < ActionController::API
  include GDS::SSO::ControllerMethods

  class CapturedSensitiveException < StandardError
    attr_reader :captured

    def initialize(captured)
      super()
      @captured = captured
    end
  end

  before_action :authorise_sso_user!

  rescue_from ApiError::Base do |error|
    render status: error.status_code, json: {
      type: error.type,
      title: error.title,
      detail: error.detail,
    }.merge(error.extra_detail)
  end

  rescue_from CapturedSensitiveException do |error|
    GovukError.notify("CapturedSensitiveException", { tags: { sensitive_exception_id: error.captured.id } })
    head :internal_server_error
  end

private

  def authorise_sso_user!
    authorise_user!("internal_app")
  end

  def capture_sensitive_exceptions
    yield
  rescue StandardError => e
    captured = SensitiveException.create!(
      message: e.message,
      full_message: e.full_message,
    )
    raise CapturedSensitiveException, captured
  end
end
