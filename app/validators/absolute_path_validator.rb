class AbsolutePathValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if value.blank?

    record.errors.add(attribute, "must only include URL path") unless valid_absolute_url_path? value
  end

private

  def valid_absolute_url_path?(value)
    value.starts_with?("/") && URI.parse(value).path == value
  rescue URI::InvalidURIError
    false
  end
end
