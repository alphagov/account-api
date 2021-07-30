RSpec.describe SendEmailWorker do
  let(:address) { "email@example.com" }
  let(:message_subject) { "An Email from Us to You" }
  let(:body) { "Email\nBody\nGoes\nHere" }

  it "logs the message to INFO" do
    logged_message = <<~INFO
      To: #{address}
      Subject: #{message_subject}

      --

      #{body}
    INFO

    allow(Rails.logger).to receive(:info)
    described_class.new.perform(address, message_subject, body)
    expect(Rails.logger).to have_received(:info).with(logged_message)
  end

  context "with Rails.env.production? true" do
    before { allow(Rails.env).to receive(:production?).and_return(true) }

    it "calls GOV.UK Notify" do
      client = instance_double("Notifications::Client")
      allow(Notifications::Client).to receive(:new).with(Rails.application.secrets.govuk_notify_api_key).and_return(client)
      allow(client).to receive(:send_email)
      described_class.new.perform(address, message_subject, body)
      expect(client).to have_received(:send_email).with(
        email_address: address,
        template_id: Rails.application.secrets.govuk_notify_template_id,
        personalisation: {
          subject: message_subject,
          body: body,
        },
      )
    end
  end
end
