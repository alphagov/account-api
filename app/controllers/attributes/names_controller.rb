class Attributes::NamesController < AttributesController
  def show
    attributes = params.fetch(:attributes)
    validate_attributes!(attributes, :check)

    render_api_response values: @govuk_account_session.get_attributes(attributes).keys
  end
end
