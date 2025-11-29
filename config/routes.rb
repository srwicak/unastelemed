Rails.application.routes.draw do
  get "medical_staff/index"
  get "medical_staff/show"
  get "medical_staff/doctors"
  get "medical_staff/nurses"
  # Frontend routes for web application
  root "pages#landing"
  
  # Hospital Portal
  get 'hospital_portal', to: 'pages#hospital_portal'
  post 'hospital/login', to: 'sessions#hospital_login', as: 'hospital_login'
  
  # Authentication routes (untuk pasien)
  get 'login', to: 'sessions#new'
  post 'login', to: 'sessions#create'
  get 'logout', to: 'sessions#destroy'
  delete 'logout', to: 'sessions#destroy'
  get 'forgot_password', to: 'sessions#forgot_password'
  post 'forgot_password', to: 'sessions#send_reset_password'
  get 'register', to: 'users#new'
  post 'register', to: 'users#create'
  
  # Dashboard routes
  get 'dashboard', to: 'dashboard#index'
  get 'doctor_dashboard', to: 'dashboard#doctor_dashboard'
  get 'nurse_dashboard', to: 'dashboard#nurse_dashboard'
  get 'patient_dashboard', to: 'dashboard#patient_dashboard'
  get 'hospital_manager_dashboard', to: 'dashboard#hospital_manager_dashboard'
  get 'superuser_dashboard', to: 'dashboard#superuser_dashboard'
  post 'create_session', to: 'dashboard#create_session'
  get 'view_recording/:session_id', to: 'dashboard#view_recording', as: 'view_recording'
  post 'add_interpretation', to: 'dashboard#add_interpretation'
  patch 'complete_session/:id', to: 'dashboard#complete_session', as: 'complete_session'
  post 'terminate_recording/:session_id', to: 'dashboard#terminate_recording', as: 'terminate_recording'
  
  # Patient management routes
  resources :patients do
    member do
      get :medical_history
      get :recordings
      post :generate_qr
    end
  end
  
  # Recording management routes
  resources :recordings do
    member do
      get :chart
      get :data
      post :start
      post :stop
      post :add_interpretation
      put :update_status
    end
    resources :annotations, only: [:index, :create, :destroy]
  end
  
  # QR Code routes
  resources :qr_codes, only: [:index, :show, :new, :create] do
    member do
      post :use
      get :session_data
    end
  end
  
  # Session-based QR Code route
  get 'session/:session_id/qr', to: 'qr_codes#show_by_session', as: 'session_qr'
  
  # Hospital management routes
  resources :hospitals do
    member do
      get :add_staff
      post :create_staff
    end
  end
  
  # Medical staff routes
  get 'medical_staff', to: 'medical_staff#index'
  get 'medical_staff/doctors', to: 'medical_staff#doctors'
  get 'medical_staff/nurses', to: 'medical_staff#nurses'
  
  # Medical staff registration routes (untuk self-registration dengan approval)
  resources :medical_staff_registrations, only: [:index, :new, :create, :show] do
    member do
      patch :approve
      patch :reject
    end
  end

  # API routes for mobile app integration
  namespace :api do
    # Authentication endpoints
    post 'auth/register', to: 'auth#register'
    post 'auth/login', to: 'auth#login'
    post 'auth/logout', to: 'auth#logout'
    post 'auth/forgot_password', to: 'auth#forgot_password'
    get 'auth/profile', to: 'auth#profile'
    put 'auth/profile', to: 'auth#update_profile'
    post 'auth/validate_token', to: 'auth#validate_token'
    
    # Session endpoints (for mobile app)
    post 'sessions/validate_qr', to: 'sessions#validate_qr'
    
    # Device endpoints (for mobile app)
    post 'devices/scan', to: 'devices#scan'
    get 'devices/status/:device_id', to: 'devices#status'
    
    # QR Code endpoints
    resources :qr_codes, only: [:index, :show, :create, :update] do
      member do
        post :validate
        post :use
      end
      collection do
        post :validate_by_code
      end
    end
    
    # Patient management
    resources :patients, only: [:index, :show, :create, :update] do
      member do
        get :recordings
        get :medical_history
      end
    end
    
    # Recording sessions - Mobile App Endpoints
    resources :recordings, only: [:index, :show, :create, :update, :destroy] do
      member do
        post :stop
        get :data
        get :chart_data
        get :batches
        post :complete
        post :cancel
        put :add_interpretation
        put :add_notes
        post :recover_data  # NEW: endpoint untuk upload data yang tertinggal
        post :force_complete # NEW: endpoint untuk force complete recording yang stuck
      end
      collection do
        post :start
        post :stop
        post :data
        get :stale # NEW: list recording yang stuck
      end
      
      # EKG Markers (nested under recordings)
      resources :markers, controller: 'ekg_markers', only: [:index, :create] do
        collection do
          get :summary
        end
      end
    end
    
    # EKG Markers (direct access)
    resources :ekg_markers, only: [:show, :update, :destroy], path: 'markers'
    
    # Chunked upload endpoints
    post 'upload/init', to: 'uploads#init'
    put 'upload/chunk', to: 'uploads#chunk'
    post 'upload/complete', to: 'uploads#complete'
    get 'upload/status/:upload_id', to: 'uploads#status'
    
    # Hospital management
    resources :hospitals, only: [:index, :show]
    
    # Medical staff
    resources :medical_staff, only: [:index, :show] do
      collection do
        get :doctors
        get :nurses
      end
    end
  end
  
  # Defines the root path route ("/")
  # root "posts#index"
end
