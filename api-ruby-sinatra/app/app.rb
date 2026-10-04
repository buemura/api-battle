require "json"
require "logger"
require "sinatra/base"
require_relative "db"

module ApiBattle
  # Every non-2xx response is rendered as `{"error": "<message>"}`.
  class ApiError < StandardError
    attr_reader :status

    def initialize(status, message)
      super(message)
      @status = status
    end
  end

  class App < Sinatra::Base
    MAX_BIGINT = 2**63 - 1
    DEFAULT_PAGE_SIZE = 20
    MAX_PAGE_SIZE = 100
    DIGITS = /\A[0-9]+\z/
    PAGINATION_ERROR = "'page' must be >= 1 and 'page_size' must be between 1 and 100".freeze
    TYPE_ERROR = "'type' must be either 'credit' or 'debit'".freeze
    AMOUNT_ERROR = "'amount' must be a positive integer (minor units, e.g. cents)".freeze
    DESCRIPTION_ERROR = "'description' must be a string of at most 255 characters".freeze

    # The hand-written spec is shared by every implementation of this API.
    SPEC = File.read(File.expand_path("../openapi.yaml", __dir__)).freeze
    DOCS_UI = <<~HTML.freeze
      <!doctype html>
      <html lang="en">
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>ApiBattle API Docs</title>
        <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/swagger-ui-dist@5.33.1/swagger-ui.css">
      </head>
      <body>
        <div id="swagger-ui"></div>
        <script src="https://cdn.jsdelivr.net/npm/swagger-ui-dist@5.33.1/swagger-ui-bundle.js"></script>
        <script>
          window.ui = SwaggerUIBundle({ url: 'openapi.yaml', dom_id: '#swagger-ui' });
        </script>
      </body>
      </html>
    HTML

    LOGGER = Logger.new($stdout, level: ENV.fetch("LOG_LEVEL", "warn"))

    configure do
      set :logging, false
      set :show_exceptions, false
      set :raise_errors, false
      set :dump_errors, false
      set :default_content_type, "application/json"
      # A JSON API serves no browser sessions or forms, so Rack::Protection's
      # CSRF/XSS middleware has nothing to protect.
      set :protection, false
      set :x_cascade, false
    end

    get "/health" do
      content_type :text
      "ok"
    end

    get "/docs" do
      content_type :html
      DOCS_UI
    end

    get "/openapi.yaml" do
      content_type "application/yaml"
      SPEC
    end

    get "/accounts" do
      accounts = paginate(Account.with_balance.order(:id)).all
      render_page(accounts, Account.count)
    end

    get "/accounts/:id" do
      account = Account.with_balance.where(id: path_id(:id)).first or raise not_found_error("account not found")
      json account.to_h
    end

    get "/accounts/:id/transactions" do
      account_id = path_id(:id)
      Account.where(id: account_id).select(:id).first or raise not_found_error("account not found")
      scope = Transaction.where(account_id:)
      render_page(paginate(scope.reverse(:id)).all, scope.count)
    end

    post "/accounts/:id/transactions" do
      account_id = path_id(:id)
      input = transaction_params

      transaction = DB.transaction do
        # Lock the account row so concurrent debits can't overdraw it.
        Account.where(id: account_id).select(:id).for_update.first or raise not_found_error("account not found")

        if input[:type] == "debit" && Transaction.balance_of(account_id) < input[:amount]
          raise ApiError.new(422, "insufficient funds")
        end

        Transaction.create(account_id:, **input)
      end

      status 201
      json transaction.to_h
    end

    get "/transactions/:id" do
      transaction = Transaction.with_pk(path_id(:id)) or raise not_found_error("transaction not found")
      json transaction.to_h
    end

    not_found do
      json error: "not found"
    end

    error ApiError do
      error = env["sinatra.error"]
      status error.status
      json error: error.message
    end

    error StandardError do
      error = env["sinatra.error"]
      LOGGER.error("unhandled error: #{error.class}: #{error.message}\n#{error.backtrace&.first(10)&.join("\n")}")
      status 500
      json error: "internal server error"
    end

    private

    def json(payload)
      JSON.generate(payload)
    end

    def not_found_error(message) = ApiError.new(404, message)

    # Non-numeric ids can never match a resource, so they are a 404, not a 400.
    def path_id(key)
      raw = params[key].to_s
      raise not_found_error("not found") unless raw.match?(DIGITS) && raw.to_i <= MAX_BIGINT

      raw.to_i
    end

    def pagination
      @pagination ||= begin
        page = positive_query_param("page", 1)
        page_size = positive_query_param("page_size", DEFAULT_PAGE_SIZE)
        raise ApiError.new(400, PAGINATION_ERROR) if page.nil? || page_size.nil? || page_size > MAX_PAGE_SIZE

        { page:, page_size:, offset: (page - 1) * page_size }
      end
    end

    def positive_query_param(name, fallback)
      raw = request.GET[name]
      return fallback if raw.nil? || raw == ""
      return nil unless raw.is_a?(String) && raw.match?(DIGITS) && raw.to_i >= 1

      raw.to_i
    end

    def paginate(dataset)
      dataset.limit(pagination[:page_size], pagination[:offset])
    end

    def render_page(rows, total)
      json data: rows.map(&:to_h), page: pagination[:page], page_size: pagination[:page_size], total:
    end

    # Parses the raw body as JSON whatever its content type, so field types are
    # checked strictly (e.g. "100" or 1.5 are not valid amounts).
    def transaction_params
      body = begin
        JSON.parse(request.body.read)
      rescue JSON::ParserError
        raise ApiError.new(400, "request body must be JSON")
      end
      raise ApiError.new(400, "request body must be a JSON object") unless body.is_a?(Hash)

      type, amount, description = body.values_at("type", "amount", "description")
      raise ApiError.new(400, TYPE_ERROR) unless Transaction::TYPES.include?(type)
      raise ApiError.new(400, AMOUNT_ERROR) unless amount.is_a?(Integer) && amount.between?(1, MAX_BIGINT)
      unless description.nil? || (description.is_a?(String) && description.length <= 255)
        raise ApiError.new(400, DESCRIPTION_ERROR)
      end

      { type:, amount:, description: description.nil? || description.strip.empty? ? nil : description }
    end
  end
end
