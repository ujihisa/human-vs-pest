Rails.application.routes.draw do
  match 'game_matches/live', to: 'game_matches#live', via: [:get, :connect]
  resources :game_matches, only: [:index, :show, :new, :create]

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  root "game_matches#new"

  get '/you', to: 'you#show'
  put '/you', to: 'you#update'
end
