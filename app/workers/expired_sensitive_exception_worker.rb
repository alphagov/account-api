class ExpiredSensitiveExceptionWorker < ApplicationWorker
  def perform
    SensitiveException.expired.delete_all
  end
end
