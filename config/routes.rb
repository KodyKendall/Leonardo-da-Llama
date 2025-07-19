Rails.application.routes.draw do
  resources :contacts
  resources :messages
  # resources :users
  devise_for :users, controllers: { registrations: 'users/registrations' }

  resources :organizations
  mount LlamaBotRails::Engine => "/llama_bot"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  # Defines the root path route ("/")
  # root "posts#index"

  root "messages#home"
  get "messages/home" => "messages#home"

    resources :twilio do
    collection do
      get :get_available_twilio_phone_numbers_for_purchase
      post :message_status_from_twilio
      post :purchase_available_phone_number
    end
  end

  post "inbound_sms" => "messages#inbound_sms"

end