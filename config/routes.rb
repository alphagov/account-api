Rails.application.routes.draw do
  get "/healthcheck", to: GovukHealthcheck.rack_response(
    GovukHealthcheck::ActiveRecord,
  )

  scope :api do
    scope :oauth2 do
      get "/sign-in", to: "authentication#sign_in"
      post "/callback", to: "authentication#callback"
      post "/state", to: "authentication#create_state"
    end
  end
end
