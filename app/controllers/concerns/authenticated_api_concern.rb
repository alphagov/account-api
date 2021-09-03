module AuthenticatedApiConcern
  extend ActiveSupport::Concern

  included do
    before_action do
      @govuk_account_session = AccountSession.deserialise(
        encoded_session: get_govuk_account_session(request),
        session_secret: Rails.application.secrets.session_secret,
      )

      head :unauthorized unless @govuk_account_session
    end

    rescue_from OidcClient::OAuthFailure do
      head :unauthorized
    end
  end

  def render_api_response(options = {})
    render json: options.merge(govuk_account_session: @govuk_account_session.serialise)
  end

  def get_govuk_account_session(request)
    if request.headers["HTTP_GOVUK_ACCOUNT_SESSION"].nil? && Rails.env.development?
      return request.cookies["govuk_account_session"]
    end

    request.headers["HTTP_GOVUK_ACCOUNT_SESSION"]
  end
end
