class Attributes::NamesController < AttributesController
  def show
    local_attributes, remote_attributes = get_attributes_from_params(
      params.fetch(:attributes),
      permission_level: :check,
    )

    values = @govuk_account_session.get_local_attributes(local_attributes)
      .merge(@govuk_account_session.get_remote_attributes(remote_attributes))

    render_api_response values: values.compact.keys
  end
end
