class ApplicationController < ActionController::API
  class CapturedSensitiveException < StandardError
    attr_reader :captured

    def initialize(captured)
      super()
      @captured = captured
    end
  end

  rescue_from CapturedSensitiveException do |error|
    GovukError.notify("CapturedSensitiveException", { extra: { sensitive_exception_id: error.captured.id } })
    head :internal_server_error
  end

private

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
