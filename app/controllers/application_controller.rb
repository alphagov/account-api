class ApplicationController < ActionController::API
  class CapturedSensitiveException < StandardError; end

  rescue_from CapturedSensitiveException do
    head :internal_server_error
  end

private

  def capture_sensitive_exceptions(user)
    yield
  rescue StandardError => e
    Sentry.with_scope do |scope|
      scope.set_user(id: user.sub)

      captured = SensitiveException.create!(
        message: e.message,
        full_message: e.full_message,
      )
      GovukError.notify("CapturedSensitiveException", { extra: { sensitive_exception_id: captured.id } })

      raise CapturedSensitiveException
    end
  end
end
