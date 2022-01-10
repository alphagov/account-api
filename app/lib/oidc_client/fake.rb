class OidcClient::Fake < OidcClient
  class NoDevelopmentUser < OAuthFailure; end

  attr_reader :authorization_endpoint,
              :token_endpoint,
              :userinfo_endpoint,
              :end_session_endpoint

  def initialize
    super

    @frontend = Plek.find("frontend")
    @authorization_endpoint = @frontend
    @token_endpoint = @frontend
    @userinfo_endpoint = @frontend
    @end_session_endpoint = @frontend
  end

  def auth_uri(auth_request, mfa: false)
    "#{@frontend}/sign-in/callback?state=#{auth_request.to_oauth_state}&code=#{mfa ? 'with-mfa' : 'without-mfa'}"
  end

  def callback(auth_request, code)
    tokens!(oidc_nonce: auth_request.oidc_nonce).merge(mfa: code == "with-mfa")
  end

  def tokens!(oidc_nonce: nil)
    user = OidcUser.first || create_user

    if oidc_nonce
      id_token_jwt = "id-token-jwt"
      id_token = Struct.new(:sub).new(user.sub)
    end

    {
      access_token: user.sub,
      id_token_jwt: id_token_jwt,
      id_token: id_token,
    }.compact
  end

  def userinfo(access_token:, **_)
    user = OidcUser.find_by(sub: access_token)
    raise NoDevelopmentUser unless user

    {
      "sub" => user.sub,
      "email" => user.email,
      "email_verified" => user.email_verified,
    }
  end

private

  def create_user
    OidcUser.create!(
      sub: SecureRandom.uuid,
      email: "email@example.com",
      email_verified: true,
    )
  end
end
