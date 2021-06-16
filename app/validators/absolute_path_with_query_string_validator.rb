class AbsolutePathWithQueryStringValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if value.blank?

    if value.starts_with? "//"
      record.errors.add(attribute, "can't be protocol-relative")
      return
    end

    return if value.starts_with? "/"
    return if value.starts_with?("http://") && Rails.env.development?

    record.errors.add(attribute, "can't be absolute")
  end
end
