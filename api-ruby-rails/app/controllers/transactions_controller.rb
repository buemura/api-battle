class TransactionsController < ApplicationController
  TYPE_ERROR = "'type' must be either 'credit' or 'debit'".freeze
  AMOUNT_ERROR = "'amount' must be a positive integer (minor units, e.g. cents)".freeze
  DESCRIPTION_ERROR = "'description' must be a string of at most 255 characters".freeze

  def index
    account = Account.select(:id).find_by(id: path_id(:account_id)) or raise ApiError.not_found("account not found")
    transactions = paginate(account.transactions.order(id: :desc)).to_a
    render_page(transactions, account.transactions.count)
  end

  def create
    account_id = path_id(:account_id)
    input = transaction_params

    transaction = ActiveRecord::Base.transaction do
      # Lock the account row so concurrent debits can't overdraw it.
      Account.lock.select(:id).find_by(id: account_id) or raise ApiError.not_found("account not found")

      if input[:type] == "debit" && Transaction.balance_of(account_id) < input[:amount]
        raise ApiError.unprocessable("insufficient funds")
      end

      Transaction.create!(account_id:, **input)
    end

    render json: transaction, status: :created
  end

  def show
    transaction = Transaction.find_by(id: path_id) or raise ApiError.not_found("transaction not found")
    render json: transaction
  end

  private

  # Parses the raw body as JSON whatever its content type, so field types are
  # checked strictly (e.g. "100" or 1.5 are not valid amounts).
  def transaction_params
    body = begin
      JSON.parse(request.raw_post.to_s)
    rescue JSON::ParserError
      raise ApiError.bad_request("request body must be JSON")
    end
    raise ApiError.bad_request("request body must be a JSON object") unless body.is_a?(Hash)

    type, amount, description = body.values_at("type", "amount", "description")
    raise ApiError.bad_request(TYPE_ERROR) unless Transaction::TYPES.include?(type)
    raise ApiError.bad_request(AMOUNT_ERROR) unless amount.is_a?(Integer) && amount.between?(1, MAX_BIGINT)
    unless description.nil? || (description.is_a?(String) && description.length <= 255)
      raise ApiError.bad_request(DESCRIPTION_ERROR)
    end

    { type:, amount:, description: description.presence }
  end
end
