# frozen_string_literal: true

class AccountSession
  include DigitalIdentityHelper

  class Frozen < StandardError; end

  class CannotSetRemoteDigitalIdentityAttributes < StandardError; end

  LOWEST_LEVEL_OF_AUTHENTICATION = "level0"

  attr_reader :user_id, :level_of_authentication

  def initialize(session_signing_key:, access_token:, refresh_token:, level_of_authentication:, user_id: nil)
    @session_signing_key = session_signing_key
    @access_token = access_token
    @refresh_token = refresh_token
    @level_of_authentication = level_of_authentication
    @frozen = false

    @user_id = user_id || userinfo["sub"]
  end

  def self.deserialise(encoded_session:, session_signing_key:)
    encoded_session_without_flash = encoded_session&.split("$$")&.first
    return if encoded_session_without_flash.blank?

    serialised_session = StringEncryptor.new(signing_key: session_signing_key).decrypt_string(encoded_session_without_flash)
    if serialised_session
      new(
        session_signing_key: session_signing_key,
        **{
          level_of_authentication: LOWEST_LEVEL_OF_AUTHENTICATION,
        }.merge(JSON.parse(serialised_session).symbolize_keys),
      )
    end
  rescue OidcClient::OAuthFailure
    nil
  end

  def user
    @user ||= OidcUser.find_or_create_by!(sub: user_id)
  end

  def level_of_authentication_as_integer
    @level_of_authentication_as_integer ||= LevelOfAuthentication.name_to_integer level_of_authentication
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

  def get_attributes(attribute_names)
    local = attribute_names.select { |name| user_attributes.type(name) == "local" }
    remote = attribute_names.select { |name| user_attributes.type(name) == "remote" }
    cached = attribute_names.select { |name| user_attributes.type(name) == "cached" }

    if cached
      values_already_cached = user.get_local_attributes(cached)
      values_to_cache = get_remote_attributes(cached.reject { |name| values_already_cached.key? name })
      user.set_local_attributes(values_to_cache)
      values = values_already_cached.merge(values_to_cache)
    else
      values = {}
    end

    values.merge(user.get_local_attributes(local).merge(get_remote_attributes(remote))).compact
  end

  def set_attributes(attributes)
    local = attributes.select { |name| user_attributes.type(name) == "local" }
    remote = attributes.select { |name| user_attributes.type(name) == "remote" }
    cached = attributes.select { |name| user_attributes.type(name) == "cached" }

    if cached
      user.set_local_attributes(cached)
      set_remote_attributes(cached)
    end

    user.set_local_attributes(local)
    set_remote_attributes(remote)
  end

private

  attr_reader :session_signing_key

  def get_remote_attributes(remote_attributes)
    values = remote_attributes.index_with do |name|
      if userinfo.key? name
        userinfo[name]
      elsif using_digital_identity?
        # TODO: Digital Identity currently returns all attributes in
        # the UserInfo.  We should change this logic so that:
        #
        # - if they say that will always be the case, remove the
        # fallback and always lookup in UserInfo.
        # - if they say that will change, implement their API.
        nil
      else
        oidc_do :get_attribute, { attribute: name }
      end
    end

    values.compact
  end

  def set_remote_attributes(remote_attributes)
    return if remote_attributes.empty?

    # TODO: Digital Identity currently have no way to set remote
    # attributes.  We don't have any writable remote attributes at the
    # moment so this isn't a problem.  But when they do, implement
    # their API.
    if using_digital_identity?
      raise CannotSetRemoteDigitalIdentityAttributes, remote_attributes
    else
      oidc_do :bulk_set_attributes, { attributes: remote_attributes }
    end
  end

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

  def userinfo
    @userinfo ||= oidc_do :userinfo
  end

  def oidc_client
    @oidc_client ||= oidc_client_class.new
  end

  def user_attributes
    @user_attributes ||= UserAttributes.new
  end
end
