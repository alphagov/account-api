FactoryBot.define do
  factory :saved_page do
    oidc_user
    sequence(:page_path) { |n| "/page-path/#{n}" }
    content_id { SecureRandom.uuid }
    sequence(:title) { |n| "Page #{n}" }
  end
end
