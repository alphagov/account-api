namespace :support do
  desc "Check if a user exists for the given email address"
  task :find_user, [:email] => :environment do |_, args|
    if OidcUser.find_by("lower(email) = ?", args[:email].downcase)
      puts "User '#{args[:email]}' exists"
    else
      puts "User '#{args[:email]}' does not exist"
    end
  end
end
