class LogoutNotice
  def self.find(sub)
    Redis.current.get("logout-notice/#{sub}")
  end

  def initialize(sub)
    @sub = sub
  end

  def persist
    Redis.current.set("logout-notice/#{sub}", Time.zone.now)
  end

  def remove
    Redis.current.del("logout-notice/#{sub}")
  end

private

  attr_reader :sub
end
