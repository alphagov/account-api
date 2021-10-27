namespace :support do
  desc "Check if a user exists for the given email address"
  task :find_user, [:email] => :environment do |_, args|
    if OidcUser.find_by("lower(email) = ?", args[:email].downcase)
      puts "User '#{args[:email]}' exists"
    else
      puts "User '#{args[:email]}' does not exist"
    end
  end

  desc "Get a user's Transition Checker results"
  task :tc_results, [:email] => :environment do |_, args|
    user = OidcUser.find_by("lower(email) = ?", args[:email].downcase)
    abort "User does not exist" unless user

    criteria_keys = user.transition_checker_state&.dig("criteria_keys")
    abort "User has no saved transition checker answers" unless criteria_keys

    puts "https://www.gov.uk/transition-check/results?#{Rack::Utils.build_nested_query(c: criteria_keys)}"
  end
end
