Rails.application.routes.draw do
  get "/healthcheck", to: GovukHealthcheck.rack_response(
    GovukHealthcheck::ActiveRecord,
  )
end
