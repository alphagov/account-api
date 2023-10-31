namespace :support do
  desc "Check if a user exists for the given email address"
  task :find_user, [:email] => :environment do |_, args|
    if OidcUser.find_by("lower(email) = ?", args[:email].downcase)
      puts "User '#{args[:email]}' exists"
    else
      puts "User '#{args[:email]}' does not exist"
    end
  end

  namespace :delete_user do
    desc "Dry Run to delete user for the given email address"
    task :dry_run, [:email] => :environment do |_, args|
      user = OidcUser.find_by("lower(email) = ?", args[:email].downcase)
      if user
        puts "Dry Run: User '#{user.email}' would have been deleted"
        puts "Dry Run: User sub: #{user.sub}"
      else
        puts "User '#{args[:email]}' does not exist"
      end
    end

    desc "Delete user for the given email address"
    task :real, [:email] => :environment do |_, args|
      user = OidcUser.find_by("lower(email) = ?", args[:email].downcase)
      if user
        begin
          subscriber = GdsApi.email_alert_api.find_subscriber_by_govuk_account(
            govuk_account_id: user.id,
          )

          GdsApi.email_alert_api.unsubscribe_subscriber(
            subscriber.dig("subscriber", "id"),
          )
        rescue GdsApi::HTTPNotFound
          # No linked email-alert-api account, nothing to do
          nil
        end

        user.destroy!

        puts "User '#{user.email}' deleted"
        puts "User sub: #{user.sub}"
      else
        puts "User '#{args[:email]}' does not exist"
      end
    end
  end

  desc "Check if a user previously existed for a given OICD sub"
  task :find_deleted_user_by_oicd_sub, [:sub] => :environment do |_, args|
    tombstone = Tombstone.find_by(sub: args[:sub])
    if tombstone
      puts "User was deleted at #{tombstone.created_at.to_formatted_s(:db)}"
    else
      puts "No deleted user for sub '#{args[:sub]}' found"
    end
  end
end
