Rails.application.routes.draw do
  get 'up' => 'rails/health#show', as: :rails_health_check

  root 'ask#index'

  get 'ask' => 'ask#ask', as: :ask
end
