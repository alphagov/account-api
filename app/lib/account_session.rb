# frozen_string_literal: true

class AccountSession
  class Frozen < StandardError; end

  LOWEST_LEVEL_OF_AUTHENTICATION = "level0"

  attr_reader :user_id, :level_of_authentication

  def initialize(session_signing_key:, access_token:, refresh_token:, level_of_authentication:, user_id: nil)
    @session_signing_key = session_signing_key
    @access_token = access_token
    @refresh_token = refresh_token
    @level_of_authentication = level_of_authentication
    @frozen = false

    @user_id = user_id || oidc_do(:userinfo)["sub"]
  end

  def self.deserialise(encoded_session:, session_signing_key:)
    return if encoded_session.blank?

    serialised_session = StringEncryptor.new(signing_key: session_signing_key).decrypt_string(encoded_session)
    if serialised_session
      new(
        session_signing_key: session_signing_key,
        **{
          level_of_authentication: LOWEST_LEVEL_OF_AUTHENTICATION,
        }.merge(JSON.parse(serialised_session).symbolize_keys),
      )
    else
      deserialise_legacy_base64_session(
        encoded_session: encoded_session,
        session_signing_key: session_signing_key,
      )
    end
  end

  def self.deserialise_legacy_base64_session(encoded_session:, session_signing_key:)
    bits = (encoded_session || "").split(".")
    if bits.length == 2
      new(
        session_signing_key: session_signing_key,
        access_token: Base64.urlsafe_decode64(bits[0]),
        refresh_token: Base64.urlsafe_decode64(bits[1]),
        level_of_authentication: LOWEST_LEVEL_OF_AUTHENTICATION,
      )
    end
  rescue ArgumentError
    nil
  end

  def serialise
    @frozen = true
    StringEncryptor.new(signing_key: session_signing_key).encrypt_string(to_hash.to_json)
  end

  def to_hash
    {
      user_id: user_id,
      access_token: @access_token,
      refresh_token: @refresh_token,
      level_of_authentication: level_of_authentication,
    }
  end

  def get_remote_attributes(remote_attributes)
    remote_attributes.index_with { |name| oidc_do :get_attribute, { attribute: name } }
  end

  def set_remote_attributes(remote_attributes)
    return if remote_attributes.empty?

    oidc_do :bulk_set_attributes, { attributes: remote_attributes }
  end

  def has_email_subscription?
    oidc_do :has_email_subscription
  end

  def set_email_subscription(slug)
    oidc_do :update_email_subscription, { slug: slug }
  end

private

  attr_reader :session_signing_key

  def oidc_do(method, args = {})
    raise Frozen if @frozen

    oauth_response = oidc_client.public_send(
      method,
      **args.merge(access_token: @access_token, refresh_token: @refresh_token),
    )
    @access_token = oauth_response[:access_token]
    @refresh_token = oauth_response[:refresh_token]
    oauth_response[:result]
  end

  def oidc_client
    @oidc_client ||= OidcClient.new
  end
end
