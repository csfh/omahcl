Rails.application.routes.draw do
  resource :session, only: %i[new create destroy]
  get "up" => "rails/health#show", as: :rails_health_check
  get "collect", to: "collects#show"
  get "challenges", to: "challenges#create"
  post "reports", to: "reports#create"
  resources :hardware_models, path: "models", param: :slug, only: %i[index show] do
    get :suggestions, on: :collection
  end
  get "privacy", to: "pages#privacy", as: :privacy
  namespace :admin do
    root to: "dashboards#show"
    resources :users, only: %i[index show destroy] do
      post :grant_admin, on: :member
      post :revoke_admin, on: :member
    end
    resources :reports, only: %i[index show], param: :public_id
    resources :challenges, only: %i[index show]
  end
  root "pages#home"
end
