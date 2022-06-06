class OidcEventsController < ApplicationController
  def backchannel_logout
    logout_token = oidc_client.logout_token(logout_token)
    if logout_token
      user_id = logout_token[:logout_token].sub
      LogoutNotice.new(user_id).persist
      head :ok
    end
  rescue OidcClient::BackchannelLogoutFailure
    head :bad_request
  end

private

  def logout_token
    params.require(:logout_token)
  end

  def oidc_client
    @oidc_client ||=
      if Rails.env.development?
        OidcClient::Fake.new
      else
        OidcClient.new
      end
  end
end
