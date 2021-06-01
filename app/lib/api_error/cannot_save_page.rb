module ApiError
  class CannotSavePage < ApiError::Base
    attr_reader :page_path, :errors

    def initialize(page_path:, errors:)
      super
      @page_path = page_path
      @errors = errors
    end

    def status_code
      :unprocessable_entity
    end

    def detail
      I18n.t("errors.cannot_save_page.detail", page_path: page_path)
    end

    def extra_detail
      {
        page_path: page_path,
        errors: errors,
      }
    end
  end
end
