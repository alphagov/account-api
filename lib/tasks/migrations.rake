namespace :migrations do
  desc "Migrate Transition Checker state & email subscriptions from the Account Manager"
  task :transition_checker, %i[token] => [:environment] do |_, args|
    token = args.token
    Migrations::TransitionChecker.call(token)
  end
end
