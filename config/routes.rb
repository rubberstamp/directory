Rails.application.routes.draw do
  devise_for :users
  
  # Public routes
  root "home#index"
  get "home/index"
  
  resources :profiles, only: [:index, :show] do
    resources :guest_messages, only: [:create]
  end
  resources :guest_messages, only: [:create]
  resources :episodes, only: [:index, :show]
  resources :testimonials, only: [:index]
  resources :contacts, only: [:index, :create]
  resources :guest_applications, only: [:new, :create]
  resources :pages, only: [:show]
  post '/subscribe', to: 'contacts#subscribe', as: :subscribe
  get '/contact', to: 'contacts#index', as: :contact
  get '/become-a-guest', to: 'guest_applications#new', as: :become_a_guest
  get '/events', to: 'events#index', as: :events
  post '/event_registrations', to: 'registrations#create', as: :event_registrations
  get '/map', to: 'map#index', as: :map
  get '/about', to: 'about#index', as: :about
  
  # Mastermind timer
  get '/mastermind/timer', to: 'mastermind#timer', as: :mastermind_timer
  
  # Admin routes
  namespace :admin do
    get "dashboard/index"
    get '/', to: 'dashboard#index', as: :dashboard
    resources :profiles do
      member do
        post :geocode
        post :generate_bio
      end
      collection do
        get :export
        post :import
        post :geocode_all
        post :generate_all_bios
      end
    end
    resources :specializations
    resources :pages
    resources :episodes do
      member do
        post :attach_profile
        delete :detach_profile
        post :summarize # Add route for summarization
      end
      collection do
        post :import
        get :template
        get :export
        post :sync_youtube
      end
    end
    
    # Guest messages management
    resources :guest_messages do
      member do
        post :forward
      end
    end
    
    # Headshots management
    resources :headshots, only: [:index, :update] do
      member do
        post :create_placeholder
      end
      collection do
        post :run_import
        post :migrate_to_active_storage
      end
    end
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  
  # Catch-all route for dynamic pages at root level
  get '/:id', to: 'pages#show', as: :page_permalink, constraints: lambda { |req|
    # Exclude certain paths that we know are handled by other routes
    !%w[
      profiles episodes testimonials contacts guest_applications
      subscribe contact become-a-guest events map about mastermind
      rails admin up manifest service-worker
    ].include?(req.path_parameters[:id])
  }
end
