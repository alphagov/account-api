require_relative "../publishing_api_tasks"

namespace :publishing_api do
  desc "Publish special routes"
  task publish_special_routes: :environment do
    PublishingApiTasks.new.publish_special_routes
  end
end
