Rails.application.routes.draw do
  get "/healthcheck/live", to: proc { [200, {}, %w[OK]] }
  get "/healthcheck/ready", to: GovukHealthcheck.rack_response(
    GovukHealthcheck::ActiveRecord,
    GovukHealthcheck::RailsCache,
    GovukHealthcheck::SidekiqRedis,
  )

  scope :api do
    scope :oauth2 do
      get "/sign-in", to: "authentication#sign_in"
      post "/callback", to: "authentication#callback"
      get "/end-session", to: "authentication#end_session"
    end

    get "/user", to: "user#show"

    resources :oidc_users, only: %i[update destroy], param: :subject_identifier, path: "oidc-users"

    get "/attributes", to: "attributes#show"
    patch "/attributes", to: "attributes#update"

    resources :email_subscriptions, only: %i[show update destroy], param: :subscription_name, path: "email-subscriptions"

    resources :saved_pages, only: %i[index show update destroy], param: :page_path, path: "saved-pages"
  end
end
