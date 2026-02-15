Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "home#index"
  get "/top-hero.png", to: "home#top_hero_image", as: :top_hero_image
  get "/create-hero.png", to: "home#create_hero_image", as: :create_hero_image

  resources :users, only: [ :new, :create ]
  resources :sessions, only: [ :new, :create ]
  delete "/logout", to: "sessions#destroy", as: :logout

  resources :owned_cards, only: [ :index ]

  resource :battle, only: [ :new, :create, :show, :destroy ] do
    post :turn, on: :member
  end

  resources :receipts, only: [ :new, :create ]
  resources :receipt_uploads, only: [ :show ] do
    post :generate_card, on: :member
  end
  resources :cards, only: [ :show ] do
    get :image, on: :member
    post :generate_artwork, on: :member
  end
end
