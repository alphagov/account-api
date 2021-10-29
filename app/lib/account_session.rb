# frozen_string_literal: true

class AccountSession
  class ReauthenticateUserError < StandardError; end

  class SessionTooOld < ReauthenticateUserError; end

  class SessionVersionInvalid < ReauthenticateUserError; end

  class MissingCachedAttribute < ReauthenticateUserError; end

  CURRENT_VERSION = 1

  attr_reader :id_token, :user_id

  def initialize(session_secret:, **options)
    raise SessionTooOld unless options[:digital_identity_session]
    raise SessionVersionInvalid unless options[:version] == CURRENT_VERSION

    @id_token = options[:id_token]
    @session_secret = session_secret
    @mfa = options.fetch(:mfa, false)
    @user_id = options.fetch(:user_id)
  end

  def self.deserialise(encoded_session:, session_secret:)
    encoded_session_without_flash = encoded_session&.split("$$")&.first
    return if encoded_session_without_flash.blank?

    serialised_session = StringEncryptor.new(secret: session_secret).decrypt_string(encoded_session_without_flash)
    return unless serialised_session

    deserialised_options = JSON.parse(serialised_session).symbolize_keys
    return if deserialised_options.blank?

    new(session_secret: session_secret, **deserialised_options)
  rescue ReauthenticateUserError
    nil
  end

  def user
    @user ||= OidcUser.find_or_create_by_sub!(user_id)
  end

  def mfa?
    @mfa
  end

  def serialise
    StringEncryptor.new(secret: session_secret).encrypt_string(to_hash.to_json)
  end

  def to_hash
    {
      id_token: id_token,
      user_id: user_id,
      digital_identity_session: true,
      mfa: @mfa,
      version: CURRENT_VERSION,
    }
  end

  def get_attributes(attribute_names)
    values_to_cache = attribute_names.select { |name| user_attributes.type(name) == "cached" }.select { |name| user[name].nil? }
    raise MissingCachedAttribute unless values_to_cache.empty?

    user.get_attributes_by_name(attribute_names).compact
  end

  def set_attributes(attributes)
    user.update!(attributes)
  end

private

  attr_reader :session_secret

  def user_attributes
    @user_attributes ||= UserAttributes.new
  end
end
