require_relative "../publishing_api_tasks"

namespace :publishing_api do
  desc "Publish redirects"
  task publish_redirects: :environment do
    PublishingApiTasks.new.publish_redirects
  end

  desc "Publish special routes"
  task publish_special_routes: :environment do
    PublishingApiTasks.new.publish_special_routes
  end

  desc "Publish a help page"
  task :publish_help_page, [:name] => :environment do |_, args|
    PublishingApiTasks.new.publish_help_page args[:name]
  end

  desc "Publish a single special route by content_id"
  task :publish_special_route, [:content_id] => :environment do |_, args|
    PublishingApiTasks.new.publish_special_route args[:content_id]
  end
end
