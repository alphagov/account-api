module ApiError
  class UnknownAttributeNames < ApiError::Base
    def initialize(attributes:)
      @attributes = attributes
    end

    def detail
      I18n.t("errors.unknown_attribute_names.detail", attributes: @attributes.join(", "))
    end

    def extra_detail
      {
        attributes: @attributes,
      }
    end
  end
end
