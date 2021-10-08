# frozen_string_literal: true

class AccountSession
  include DigitalIdentityHelper

  class Frozen < StandardError; end

  class CannotSetRemoteDigitalIdentityAttributes < StandardError; end

  class SessionTooOld < StandardError; end

  attr_reader :id_token, :user_id, :digital_identity_session

  def initialize(session_secret:, **options)
    if options.key? :level_of_authentication
      options.merge!(mfa: options[:level_of_authentication] == "level1")
      options.delete(:level_of_authentication)
    end

    @access_token = options.fetch(:access_token)
    @id_token = options[:id_token]
    @mfa = options.fetch(:mfa, false)
    @refresh_token = options[:refresh_token]
    @user_id = options[:user_id] || userinfo["sub"]
    @digital_identity_session = options.fetch(:digital_identity_session, false)
    @session_secret = session_secret
    @frozen = false

    raise SessionTooOld if using_digital_identity? && !@digital_identity_session
  end

  def self.deserialise(encoded_session:, session_secret:)
    encoded_session_without_flash = encoded_session&.split("$$")&.first
    return if encoded_session_without_flash.blank?

    serialised_session = StringEncryptor.new(secret: session_secret).decrypt_string(encoded_session_without_flash)
    return unless serialised_session

    options = JSON.parse(serialised_session).symbolize_keys
    new(session_secret: session_secret, **options)
  rescue OidcClient::OAuthFailure, SessionTooOld
    nil
  end

  def user
    @user ||= OidcUser.find_or_create_by_sub!(
      user_id,
      legacy_sub: using_digital_identity? ? nil : user_id,
    )
  end

  def mfa?
    @mfa
  end

  def serialise
    @frozen = true
    StringEncryptor.new(secret: session_secret).encrypt_string(to_hash.to_json)
  end

  def to_hash
    {
      id_token: id_token,
      user_id: user_id,
      digital_identity_session: digital_identity_session,
      mfa: @mfa,
      access_token: @access_token,
      refresh_token: @refresh_token,
    }
  end

  def get_attributes(attribute_names)
    local = attribute_names.select { |name| user_attributes.type(name) == "local" }
    remote = attribute_names.select { |name| user_attributes.type(name) == "remote" }
    cached = attribute_names.select { |name| user_attributes.type(name) == "cached" }

    if cached
      values_already_cached = user.get_attributes_by_name(cached)
      values_to_cache = get_remote_attributes(cached.reject { |name| values_already_cached.key? name })
      user.update!(values_to_cache)
      values = values_already_cached.merge(values_to_cache)
    else
      values = {}
    end

    values.merge(user.get_attributes_by_name(local).merge(get_remote_attributes(remote))).compact
  end

  def set_attributes(attributes)
    local = attributes.select { |name| user_attributes.type(name) == "local" }
    remote = attributes.select { |name| user_attributes.type(name) == "remote" }
    cached = attributes.select { |name| user_attributes.type(name) == "cached" }

    user.update!(local.merge(cached))
    set_remote_attributes(remote.merge(cached))
  end

private

  attr_reader :session_secret

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
    @userinfo ||= begin
      userinfo_hash = oidc_do :userinfo
      if using_digital_identity?
        # TODO: Digital Identity do not have unconfirmed email
        # addresses, so this attribute is not present.  We only cache
        # non-nil attribute values, so the effect of this being
        # missing is that every request to /account/home (or another
        # page which uses this attribute) makes a userinfo request.
        # This adds latency, and gives us a 15-minute session timeout
        # as that's how long the DI access token is valid for.
        #
        # We can remove this after we have migrated to DI in
        # production and removed all use of this attribute.
        userinfo_hash.merge("has_unconfirmed_email" => false)
      else
        userinfo_hash
      end
    end
  end

  def oidc_client
    @oidc_client ||= oidc_client_class.new
  end

  def user_attributes
    @user_attributes ||= UserAttributes.new
  end
end
