class ExpiredSensitiveExceptionJob < ApplicationJob
  def perform
    SensitiveException.expired.delete_all
  end
end
