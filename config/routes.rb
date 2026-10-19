Rails.application.routes.draw do
  resource :session, only: %i[new create destroy]
  get "up" => "rails/health#show", as: :rails_health_check
  get "collect", to: "collects#show", defaults: { script: "collect" }
  get "delete", to: "collects#show", defaults: { script: "delete" }, as: :delete_script
  get "challenges", to: "challenges#create"
  post "reports", to: "reports#create"
  post "deletions", to: "deletions#create"
  resources :hardware_models, path: "models", param: :slug, only: %i[index show] do
    get :suggestions, on: :collection
  end
  get "cards/:key", to: "cards#show", as: :card, constraints: { key: /\h{16}/ }
  get "privacy", to: "pages#privacy", as: :privacy
  namespace :admin do
    root to: "dashboards#show"
    resources :users, only: %i[index show destroy] do
      post :grant_admin, on: :member
      post :revoke_admin, on: :member
    end
    resources :reports, only: %i[index show], param: :public_id do
      post :hide, on: :member
      post :unhide, on: :member
    end
  end
  root "pages#home"
end
