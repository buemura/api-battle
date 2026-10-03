defmodule ApiBattleWeb.Router do
  use ApiBattleWeb, :router

  scope "/", ApiBattleWeb do
    get "/health", HealthController, :show

    get "/accounts", AccountController, :index
    get "/accounts/:id", AccountController, :show
    get "/accounts/:account_id/transactions", TransactionController, :index
    post "/accounts/:account_id/transactions", TransactionController, :create
    get "/transactions/:id", TransactionController, :show

    get "/docs", DocsController, :swagger_ui
    get "/openapi.yaml", DocsController, :spec
  end
end
