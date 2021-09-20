module ApiError
  class MfaRequired < ApiError::Base
    def initialize(attributes:)
      super
      @attributes = attributes
    end

    def status_code
      :forbidden
    end

    def detail
      I18n.t(
        "errors.mfa_required.detail",
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
