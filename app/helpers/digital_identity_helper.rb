module DigitalIdentityHelper
  def oidc_client_class
    if using_digital_identity?
      OidcClient
    else
      OidcClient::AccountManager
    end
  end

  def using_digital_identity?
    Rails.application.secrets.oauth_client_private_key.present?
  end
end
