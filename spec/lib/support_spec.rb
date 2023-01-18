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

  describe ":delete_user" do
    before do
      FactoryBot.create(:oidc_user, email: "foo@example.gov.uk", sub: "123")
    end

    context "when a dry run" do
      subject(:task) { Rake.application["support:delete_user:dry_run"] }

      context "when a user with email exists" do
        it "reports that the user would have been deleted" do
          expect { task.execute({ email: "foo@example.gov.uk" }) }.to output("Dry Run: User 'foo@example.gov.uk' would have been deleted\nDry Run: User sub: 123\n").to_stdout
        end

        it "outputs other users don't exist" do
          expect { task.execute({ email: "bar@example.com" }) }.to output("User 'bar@example.com' does not exist\n").to_stdout
        end
      end
    end

    context "when a real run" do
      subject(:task) { Rake.application["support:delete_user:real"] }

      context "when a user with email exists" do
        it "reports that the user has been deleted" do
          expect { task.execute({ email: "foo@example.gov.uk" }) }.to output("User 'foo@example.gov.uk' deleted\nUser sub: 123\n").to_stdout
        end

        it "deletes the user" do
          count = OidcUser.count
          task.execute({ email: "foo@example.gov.uk" })
          expect(OidcUser.count).to eq count - 1
        end

        it "outputs other users don't exist" do
          expect { task.execute({ email: "bar@example.com" }) }.to output("User 'bar@example.com' does not exist\n").to_stdout
        end
      end
    end
  end
end
