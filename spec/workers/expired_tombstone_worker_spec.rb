RSpec.describe ExpiredTombstoneWorker do
  before { freeze_time }

  it "deletes old tombstones" do
    Tombstone.create!(sub: "sub", created_at: (Tombstone::EXPIRATION_AGE + 1.day).ago)
    expect { described_class.new.perform }.to change(Tombstone, :count).to(0)
  end

  it "doesn't delete recent tombstones" do
    Tombstone.create!(sub: "sub", created_at: Tombstone::EXPIRATION_AGE.ago)
    expect { described_class.new.perform }.not_to change(Tombstone, :count)
  end
end
