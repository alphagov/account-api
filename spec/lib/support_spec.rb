Rails.application.load_tasks

RSpec.describe "Support tasks" do
  describe ":find_user" do
    subject(:task) { Rake.application["support:find_user"] }

    context "when a user with email 'foo@example.gov.uk' exists" do
      before do
        FactoryBot.create(:oidc_user, email: "foo@example.gov.uk")
      end

      it "can find that user by email" do
        expect { task.execute({ email: "foo@example.gov.uk" }) }.to output("User 'foo@example.gov.uk' exists\n").to_stdout
      end

      it "outputs other users don't exist" do
        expect { task.execute({ email: "bar@example.com" }) }.to output("User 'bar@example.com' does not exist\n").to_stdout
      end

      it "performs a lowercase search for the user" do
        expect { task.execute({ email: "FOO@Example.Gov.uK" }) }.to output("User 'FOO@Example.Gov.uK' exists\n").to_stdout
      end
    end
  end
end
