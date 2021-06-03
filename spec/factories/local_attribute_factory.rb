FactoryBot.define do
  factory :local_attribute do
    oidc_user
    sequence(:name) { |n| "attibute-name-#{n}" }
    sequence(:value) { |n| { "some" => "complex", "value" => n } }
  end
end
