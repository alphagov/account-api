module ApiError
  class UnknownAttributeNames < ApiError::Base
    def initialize(attribute_names)
      @attribute_names = attribute_names
    end

    def detail
      I18n.t("errors.unknown_attribute_names.detail", attribute_names: @attribute_names.join(", "))
    end

    def extra_detail
      {
        attributes: @attribute_names,
      }
    end
  end
end
