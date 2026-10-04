class AccountsController < ApplicationController
  def index
    accounts = paginate(Account.with_balance.order(:id)).to_a
    render_page(accounts, Account.count)
  end

  def show
    account = Account.with_balance.find_by(id: path_id) or raise ApiError.not_found("account not found")
    render json: account
  end
end
