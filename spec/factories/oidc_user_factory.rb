FactoryBot.define do
  factory :oidc_user do
    sequence(:sub) { |n| "user-id-#{n}" }
  end
end
