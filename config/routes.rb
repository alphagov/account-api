Rails.application.routes.draw do
  get "/healthcheck/live", to: proc { [200, {}, %w[OK]] }
  get "/healthcheck/ready", to: GovukHealthcheck.rack_response(
    GovukHealthcheck::ActiveRecord,
    GovukHealthcheck::RailsCache,
  )

  scope :api do
    scope :oauth2 do
      get "/sign-in", to: "authentication#sign_in"
      post "/callback", to: "authentication#callback"
      post "/state", to: "authentication#create_state"
    end

    get "/user", to: "user#show"

    get "/attributes", to: "attributes#show"
    patch "/attributes", to: "attributes#update"

    namespace :attributes do
      get "/names", to: "names#show"
    end

    resources :saved_pages, only: %i[index show update destroy], param: :page_path

    get "/transition-checker-email-subscription", to: "transition_checker_email_subscription#show"
    post "/transition-checker-email-subscription", to: "transition_checker_email_subscription#update"
  end
end
