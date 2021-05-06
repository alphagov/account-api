class Attributes::NamesController < AttributesController
  def show
    remote_attributes = get_attributes_from_params(
      params.fetch(:attributes),
      permission_level: :check,
    )

    render_api_response values: @govuk_account_session.get_remote_attributes(remote_attributes).compact.keys
  end
end
