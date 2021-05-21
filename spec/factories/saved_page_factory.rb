FactoryBot.define do
  factory :saved_page do
    oidc_user
    sequence(:page_path) { |n| "/page-path/#{n}" }
  end
end
