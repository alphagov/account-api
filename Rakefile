# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

begin
  ENV["PACT_DO_NOT_TRACK"] = "true"
  require "pact/tasks"
rescue LoadError
  # Pact isn't available in all environments
end

require_relative "config/application"

Rails.application.load_tasks

Rake::Task[:default].clear if Rake::Task.task_defined?(:default)

task default: %i[lint spec pact:verify]
