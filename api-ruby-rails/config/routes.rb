Rails.application.routes.draw do
  get "health", to: "health#show"
  get "docs", to: "docs#ui"
  get "openapi.yaml", to: "docs#spec", format: false

  resources :accounts, only: %i[index show] do
    resources :transactions, only: %i[index create]
  end
  resources :transactions, only: :show

  match "*path", to: "application#route_not_found", via: :all, format: false
end
