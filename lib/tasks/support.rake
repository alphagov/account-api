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
        user.destroy!
        puts "User '#{user.email}' deleted"
        puts "User sub: #{user.sub}"
      else
        puts "User '#{args[:email]}' does not exist"
      end
    end
  end
end
