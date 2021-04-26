module ApiError
  class Base < StandardError
    def status_code
      :unprocessable_entity
    end

    def type
      I18n.t("errors.#{error_name}.type")
    end

    def title
      I18n.t("errors.#{error_name}.title")
    end

    def detail
      I18n.t("errors.#{error_name}.detail")
    end

    def extra_detail
      {}
    end

    def error_name
      self.class.name.underscore.delete_prefix "api_error/"
    end
  end
end
