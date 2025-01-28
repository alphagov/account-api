RSpec.describe ExpiredSensitiveExceptionJob do
  before { freeze_time }

  it "deletes old exceptions" do
    SensitiveException.create!(message: "foo", full_message: "bar", created_at: (SensitiveException::EXPIRATION_AGE + 1.day).ago)
    expect { described_class.new.perform }.to change(SensitiveException, :count).to(0)
  end

  it "doesn't delete recent exceptions" do
    SensitiveException.create!(message: "foo", full_message: "bar", created_at: SensitiveException::EXPIRATION_AGE.ago)
    expect { described_class.new.perform }.not_to change(SensitiveException, :count)
  end
end
