module ApiError
  class UnwritableAttributes < ApiError::Base
    def initialize(attributes:)
      super
      @attributes = attributes
    end

    def status_code
      :forbidden
    end

    def detail
      I18n.t(
        "errors.unwritable_attributes.detail",
        attributes: @attributes.join(", "),
      )
    end

    def extra_detail
      {
        attributes: @attributes,
      }
    end
  end
end
