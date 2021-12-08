FactoryBot.define do
  factory :oidc_user do
    sequence(:sub) { |n| "user-id-#{n}" }
    sequence(:email) { |n| "user-#{n}@example.com" }
    email_verified { true }
  end
end
