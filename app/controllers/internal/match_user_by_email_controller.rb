class Internal::MatchUserByEmailController < InternalController
  before_action :fetch_session_if_present

  def show
    email = params.fetch(:email).downcase

    if @govuk_account_session&.user&.email == email
      render json: { match: true }
      return
    end

    if OidcUser.where(email:).exists?
      render json: { match: false }
    else
      head :not_found
    end
  end

private

  def fetch_session_if_present
    encoded_session = request.headers[AuthenticatedApiConcern::HEADER_NAME]
    return unless encoded_session

    @govuk_account_session = AccountSession.deserialise(
      encoded_session:,
      session_secret: Rails.application.secrets.session_secret,
    )
  rescue AccountSession::ReauthenticateUserError
    @govuk_account_session = nil
  end
end
