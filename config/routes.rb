Rails.application.routes.draw do
  get "/healthcheck/live", to: proc { [200, {}, %w[OK]] }
  get "/healthcheck/ready", to: GovukHealthcheck.rack_response(
    GovukHealthcheck::ActiveRecord,
    GovukHealthcheck::RailsCache,
    GovukHealthcheck::SidekiqRedis,
  )

  scope :api do
    scope module: :internal do
      scope :oauth2 do
        get "/sign-in", to: "authentication#sign_in"
        post "/callback", to: "authentication#callback"
        get "/end-session", to: "authentication#end_session"
      end

      get "/user", to: "user#show"
      get "/user/match-by-email", to: "match_user_by_email#show"

      resources :oidc_users, only: %i[update destroy], param: :subject_identifier, path: "oidc-users"

      get "/attributes", to: "attributes#show"
      patch "/attributes", to: "attributes#update"
    end

    namespace :personalisation do
      get "check-email-subscription", to: "check_email_subscription#show", as: :check_email_subscription
    end

    scope :oidc_events do
      post "backchannel_logout", to: "oidc_events#backchannel_logout", as: :backchannel_logout
    end
  end
end
