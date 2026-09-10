Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  resource :registration, only: %i[new create]
  resources :email_verifications, only: %i[new create show], param: :token

  get "up" => "rails/health#show", as: :rails_health_check

  get "collect", to: "collects#show"
  get "challenges", to: "challenges#create"
  post "reports", to: "reports#create"
  get "reports/:public_id/claim", to: "claims#new", as: :claim_report
  post "reports/:public_id/claim", to: "claims#create"

  resources :hardware_models, path: "models", param: :slug, only: %i[index show] do
    get :suggestions, on: :collection
  end
  resources :listings, only: %i[index show]
  get "privacy", to: "pages#privacy", as: :privacy

  namespace :me do
    resources :reports, only: :index do
      resource :listing, only: %i[new create edit update]
    end
  end

  namespace :admin do
    root to: "dashboards#show"
    resources :donation_destinations, except: :show
    resources :users, only: %i[index show destroy] do
      post :verify_email, on: :member
      post :grant_admin, on: :member
      post :revoke_admin, on: :member
      post :password_reset, on: :member
    end
    resources :listings, only: %i[index show] do
      post :close, on: :member
    end
    resources :reports, only: %i[index show], param: :public_id
    resources :challenges, only: %i[index show]
  end

  root "pages#home"
end
