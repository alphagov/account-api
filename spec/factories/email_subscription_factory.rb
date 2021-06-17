FactoryBot.define do
  factory :email_subscription do
    oidc_user
    sequence(:name) { |n| "subscription-#{n}" }
    sequence(:topic_slug) { |n| "topic-#{n}" }
  end
end
