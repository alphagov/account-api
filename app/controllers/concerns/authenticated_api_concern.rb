module AuthenticatedApiConcern
  extend ActiveSupport::Concern

  HEADER_NAME = "HTTP_GOVUK_ACCOUNT_SESSION".freeze

  included do
    before_action do
      @govuk_account_session = AccountSession.deserialise(
        encoded_session: request.headers[HEADER_NAME],
        session_secret: Rails.application.credentials.session_secret,
      )

      head :unauthorized unless @govuk_account_session
    end

    rescue_from AccountSession::ReauthenticateUserError do
      head :unauthorized
    end
  end

  def render_api_response(options = {})
    render json: options.merge(govuk_account_session: @govuk_account_session.serialise)
  end
end
