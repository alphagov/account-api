require "attr_required"
require "attr_optional"

class LogoutToken
  include AttrOptional
  include AttrRequired
  class InvalidToken < RuntimeError; end
  class ExpiredToken < InvalidToken; end
  class InvalidIssuer < InvalidToken; end
  class InvalidAudience < InvalidToken; end
  class InvalidIssuedAt < InvalidToken; end
  class InvalidEvent < InvalidToken; end
  class InvalidBackchanelLogoutEvent < InvalidToken; end
  class InvalidIdentifiers < InvalidToken; end
  class TokenRecentlyUsed < InvalidToken; end
  class ProhibitedNonse < InvalidToken; end

  BACK_CHANNEL_EVENT_NAME = "http://schemas.openid.net/event/backchannel-logout".freeze

  attr_required :iss, :aud, :iat, :jti, :events
  attr_optional :sub, :sid, :auth_time
  attr_accessor :access_token, :code, :state
  alias_method :subject, :sub
  alias_method :subject=, :sub=

  NON_STRING_ATTRIBUTES = %i[aud exp iat auth_time sub_jwk events].freeze

  def initialize(attributes = {})
    attributes_to_methods(attributes)
    apply_attribute_values_types(all_attributes)
    validate_prohibited_attribtues(attributes)
  end

  def verify!(expected = {})
    validates_issuer(expected)
    validates_audience(expected)
    validates_issued_at_time
    validates_session_and_or_user_id_presence
    validates_events(expected)
    validate_jti_not_recently_used

    true
  end

private

  def attributes_to_methods(attributes)
    all_attributes.each do |attr|
      send :"#{attr}=", attributes[attr]
    end
    attr_missing!
  end

  def all_attributes
    self.class.required_attributes + self.class.optional_attributes
  end

  def apply_attribute_values_types(all_attributes)
    (all_attributes - NON_STRING_ATTRIBUTES).each do |key|
      send "#{key}=", send(key).try(:to_s)
    end
    self.iat = Time.zone.at(iat.to_i) unless iat.nil?
    self.auth_time = auth_time.to_i unless auth_time.nil?
    self.events = JSON.parse(events) unless events.nil?
  end

  def validate_prohibited_attribtues(attributes)
    raise ProhibitedNonse if attributes.keys.include?(:nonse)
  end

  # Validate iss(uer_ matches Auth's .well-known/openid-configuration
  def validates_issuer(expected = {})
    raise InvalidIssuer, "Invalid Logout token: Issuer does not match" unless iss == expected[:issuer]
  end

  # Validate aud(ience), which can be a string or an array of strings, matches client_id from registration
  def validates_audience(expected = {})
    unless Array(aud).include?(expected[:client_id]) || aud == expected[:client_id]
      raise InvalidAudience, "Invalid Logout token: Audience does not match"
    end
  end

  # Validate iat(issued at time) is in the past
  def validates_issued_at_time
    raise InvalidIssuedAt, "Invalid Logout token: Issued at does not match" unless iat.past?
  end

  # Verifiy the logout token contains SID, SUB or both.
  def validates_session_and_or_user_id_presence
    unless sub || sid
      raise InvalidIdentifiers, "Invalid Logout token: Must contain either SID, SUB or both"
    end
  end

  # Validates the logout token has a correctly formatted events claim
  def validates_events(_expected = {})
    raise InvalidBackchanelLogoutEvent, "Invalid Logout token: Events is not a hash" unless events.is_a? Hash
    unless events.keys.include?(BACK_CHANNEL_EVENT_NAME)
      raise InvalidBackchanelLogoutEvent, "Invalid Logout token: Events is not a hash"
    end

    unless events[BACK_CHANNEL_EVENT_NAME] == {}
      raise InvalidBackchanelLogoutEvent, "Invalid Logout token: Event should be the empty JSON object {}"
    end
  end

  # Verify that we've not recently recieved another request with a jti
  def validate_jti_not_recently_used
    raise TokenRecentlyUsed if is_recent_jti?(jti)

    record_jti_as_recently_verified(jti)
  end

  def is_recent_jti?(jti)
    return true if Redis.current.get("logout-token/#{jti}") == "OK"

    false
  end

  def record_jti_as_recently_verified(jti)
    Redis.current.set("logout-token/#{jti}", "OK")
    Redis.current.expire("logout-token/#{jti}", 2.minutes)
  end
end
