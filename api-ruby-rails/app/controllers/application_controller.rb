class ApplicationController < ActionController::API
  MAX_BIGINT = 2**63 - 1
  DEFAULT_PAGE_SIZE = 20
  MAX_PAGE_SIZE = 100
  DIGITS = /\A[0-9]+\z/

  rescue_from StandardError do |error|
    Rails.logger.error("unhandled error: #{error.class}: #{error.message}\n#{error.backtrace&.first(10)&.join("\n")}")
    render_error(:internal_server_error, "internal server error")
  end
  rescue_from(ApiError) { |error| render_error(error.status, error.message) }

  def route_not_found
    raise ApiError.not_found
  end

  private

  def render_error(status, message)
    render json: { error: message }, status:
  end

  # Path params are read directly so a JSON body is never parsed by Rails.
  # Non-numeric ids can never match a resource, so they are a 404, not a 400.
  def path_id(key = :id)
    raw = request.path_parameters[key].to_s
    raise ApiError.not_found unless raw.match?(DIGITS) && raw.to_i <= MAX_BIGINT

    raw.to_i
  end

  def pagination
    @pagination ||= begin
      page = positive_query_param("page", 1)
      page_size = positive_query_param("page_size", DEFAULT_PAGE_SIZE)
      if page.nil? || page_size.nil? || page_size > MAX_PAGE_SIZE
        raise ApiError.bad_request("'page' must be >= 1 and 'page_size' must be between 1 and 100")
      end

      { page:, page_size:, offset: (page - 1) * page_size }
    end
  end

  def positive_query_param(name, fallback)
    raw = request.query_parameters[name]
    return fallback if raw.blank?
    return nil unless raw.is_a?(String) && raw.match?(DIGITS) && raw.to_i >= 1

    raw.to_i
  end

  def paginate(relation)
    relation.limit(pagination[:page_size]).offset(pagination[:offset])
  end

  def render_page(data, total)
    render json: { data:, page: pagination[:page], page_size: pagination[:page_size], total: }
  end
end
