require "notifications/client"

class SendEmailWorker < ApplicationWorker
  def perform(address, subject, body)
    @address = address
    @subject = subject
    @body = body

    if send_to_notify?
      GovukStatsd.time("send_email_worker.email_send_request.notify") { send_notify_email }
    else
      send_pseudo_email
    end
  end

private

  attr_reader :address, :subject, :body

  def send_notify_email
    Notifications::Client.new(notify_api_key).send_email(
      email_address: address,
      template_id: notify_template_id,
      personalisation: {
        subject: subject,
        body: body,
      },
    )
    GovukStatsd.increment("send_email_worker.email_send_request.notify.success")
  rescue Notifications::Client::RequestError, Net::OpenTimeout, Net::ReadTimeout, SocketError => e
    GovukStatsd.increment("send_email_worker.email_send_request.notify.failure")
    raise e
  end

  def send_pseudo_email
    Rails.logger.info <<~INFO
      To: #{address}
      Subject: #{subject}

      --

      #{body}
    INFO
  end

  def send_to_notify?
    Rails.env.production?
  end

  def notify_api_key
    Rails.application.secrets.govuk_notify_api_key
  end

  def notify_template_id
    Rails.application.secrets.govuk_notify_template_id
  end
end
