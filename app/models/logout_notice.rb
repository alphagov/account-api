class LogoutNotice
  def self.find(sub)
    Redis.new.get("logout-notice/#{sub}")
  end

  def initialize(sub)
    @sub = sub
  end

  def persist
    Redis.new.set("logout-notice/#{sub}", Time.zone.now)
  end

  def remove
    Redis.new.del("logout-notice/#{sub}")
  end

private

  attr_reader :sub
end
