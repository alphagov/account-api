class OpenIdEvents < ApplicationController
  def back_channel_logout
    logout_token = oidc_client.logout_token(logout_params[:logout_token])
    if logout_token
      user_id = logout_token[:logout_token].sub
      # Make a signout notice record
      head :ok
    end

  rescue OidcClient::BackchannelLogoutFailure
    head :bad_request
  end

  private

  def logout_params
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
