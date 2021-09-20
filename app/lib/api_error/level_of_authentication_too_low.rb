module ApiError
  class LevelOfAuthenticationTooLow < ApiError::Base
    def initialize(attributes:, needed_level_of_authentication:)
      super
      @attributes = attributes
      @needed_level_of_authentication = needed_level_of_authentication
    end

    def status_code
      :forbidden
    end

    def detail
      I18n.t(
        "errors.level_of_authentication_too_low.detail",
        attributes: @attributes.join(", "),
        needed_level_of_authentication: @needed_level_of_authentication,
      )
    end

    def extra_detail
      {
        attributes: @attributes,
        needed_level_of_authentication: @needed_level_of_authentication,
      }
    end
  end
end
