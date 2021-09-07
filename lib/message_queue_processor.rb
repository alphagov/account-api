class MessageQueueProcessor
  def process(message)
    summary = process_message(message.payload)
    message.ack
    Rails.logger.info summary.to_json
  end

  # For the details of unpublishing types, the publishing-api docs are
  # the canonical source:
  # https://github.com/alphagov/publishing-api/blob/main/docs/model.md#unpublishing
  def process_message(payload)
    affected = SavedPage.where(content_id: payload["content_id"])
    affected_count = affected.count

    effect =
      case payload["document_type"]
      when "gone"
        redirect_saved_pages(affected, find_alternative_path(payload))
      when "redirect"
        redirect_saved_pages(affected, find_alternative_path(payload))
      when "vanish"
        destroy_saved_pages(affected)
      else
        update_saved_pages(affected, payload)
      end

    {
      type: payload["document_type"],
      base_path: payload["base_path"],
      content_id: payload["content_id"],
      affected_pages: affected_count,
      effect: effect,
    }
  end

  def find_alternative_path(payload)
    alternative_path = payload.dig("details", "alternative_path")
    return alternative_path if alternative_path

    exact_redirect = payload["redirects"]&.find { |r| r["type"] == "exact" && payload["base_path"] == r["path"] }
    return exact_redirect["destination"] if exact_redirect

    prefix_redirect = payload["redirects"]&.select { |r| r["type"] == "prefix" && payload["base_path"].start_with?(r["path"]) }&.max_by { |r| r["path"].length }
    if prefix_redirect
      if prefix_redirect["segments_mode"] == "preserve"
        prefix_redirect["destination"] + payload["base_path"].delete_prefix(prefix_redirect["path"])
      else
        prefix_redirect["destination"]
      end
    end
  end

  def redirect_saved_pages(saved_pages, alternative_path)
    if alternative_path
      target_content_item = GdsApi.content_store.content_item(alternative_path).to_hash

      redirected_count = 0
      destroyed_count = 0
      saved_pages.each do |page|
        page.update!(
          **SavedPage.updates_from_content_item(target_content_item).merge(
            page_path: alternative_path,
            updated_at: Time.zone.now,
          ),
        )
        redirected_count += 1
      rescue ActiveRecord::RecordInvalid
        page.destroy!
        destroyed_count += 1
      end

      "redirected #{redirected_count} to #{alternative_path} and destroyed #{destroyed_count} duplicates"
    else
      destroy_saved_pages(saved_pages)
    end
  rescue GdsApi::ContentStore::ItemNotFound, GdsApi::HTTPGone
    destroy_saved_pages(saved_pages)
  end

  def destroy_saved_pages(saved_pages)
    saved_pages.destroy_all

    "destroyed"
  end

  def update_saved_pages(saved_pages, payload)
    saved_pages.update_all(
      **SavedPage.updates_from_content_item(payload).merge(
        updated_at: Time.zone.now,
      ),
    )

    "updated"
  end
end
