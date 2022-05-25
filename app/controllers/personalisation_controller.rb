class PersonalisationController < ApplicationController
  include ActionController::Cookies if ENV["RAILS_ENV"] == "development"
  include GovukPersonalisation::ControllerConcern

  before_action do
    @govuk_account_session = AccountSession.deserialise(
      encoded_session: @account_session_header,
      session_secret: Rails.application.secrets.session_secret,
    )

    if @govuk_account_session
      end_session! if LogoutNotice.find(@govuk_account_session.user_id)
    else
      end_session!
    end
  end

  before_action :set_caching_headers

  rescue_from AccountSession::ReauthenticateUserError, with: :end_session!

private

  def set_caching_headers
    response.headers["Cache-Control"] = "no-store"
  end

  def end_session!
    logout!
    head :unauthorized
  end
end
