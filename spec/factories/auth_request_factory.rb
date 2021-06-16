FactoryBot.define do
  factory :auth_request do
    oauth_state { SecureRandom.uuid }
    oidc_nonce { SecureRandom.uuid }
  end
end
