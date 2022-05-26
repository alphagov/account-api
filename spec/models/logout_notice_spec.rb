RSpec.describe LogoutNotice do
  include ActiveSupport::Testing::TimeHelpers

  let(:sub) { "sub" }
  let(:instance) { described_class.new(sub) }
  let(:redis_formatted_time) { Time.zone.now.strftime("%F %T %z") }

  before do
    freeze_time
    Redis.current.flushdb
  end

  describe ".find" do
    it "returns nil if a Notice has not been persisted" do
      expect(described_class.find(sub)).to be_nil
    end

    it "returns the created at timestamp if a Notice has been persisted" do
      Redis.current.set("logout-notice/#{sub}", Time.zone.now)
      expect(described_class.find(sub)).to eq(redis_formatted_time)
    end
  end

  describe "#persist" do
    it "returns OK if persist went well" do
      expect(instance.persist).to eq("OK")
    end

    it "persists a sub with in a logout notice timespace with a timestamp" do
      instance.persist
      expect(Redis.current.get("logout-notice/#{sub}")).to eq(redis_formatted_time)
    end
  end

  describe "#remove" do
    it "returns 1 if the record was removed" do
      Redis.current.set("logout-notice/#{sub}", Time.zone.now)
      expect(instance.remove).to eq(1)
    end

    it "returns 0 if the records was not found" do
      expect(instance.remove).to eq(0)
    end
  end
end
