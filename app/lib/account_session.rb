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

    @user_id = user_id || userinfo["sub"]
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
      else
        oidc_do :get_attribute, { attribute: name }
      end
    end

    values.compact
  end

  def set_remote_attributes(remote_attributes)
    return if remote_attributes.empty?

    oidc_do :bulk_set_attributes, { attributes: remote_attributes }
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
    @oidc_client ||= OidcClient.new
  end

  def user_attributes
    @user_attributes ||= UserAttributes.new
  end
end
