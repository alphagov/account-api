web: bundle exec unicorn -c ./config/unicorn.rb -p ${PORT:-3000}
worker: bundle exec sidekiq -C ./config/sidekiq.yml
publishing-queue-listener: bundle exec rake message_queue:consumer
