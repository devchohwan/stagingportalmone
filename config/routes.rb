Rails.application.routes.draw do
  root "sessions#new"
  
  get "login", to: "sessions#new"
  post "login", to: "sessions#create"
  get "logout", to: "sessions#destroy"
  delete "logout", to: "sessions#destroy"
  
  get "register", to: "registrations#new"
  post "register", to: "registrations#create"
  
  get "services", to: "services#index"
  
  # 세션 전달 라우트
  get "auth/transfer", to: "auth#transfer"
  
  get "profile/edit", to: "profile#edit", as: :edit_profile
  patch "profile/update_password", to: "profile#update_password", as: :update_password
  patch "profile/update_phone", to: "profile#update_phone", as: :update_phone
  
  get "password_reset", to: "password_resets#new"
  post "password_reset", to: "password_resets#create"
  get "password_reset/edit", to: "password_resets#edit"
  patch "password_reset", to: "password_resets#update"
  
  # Admin routes
  namespace :admin do
    root "dashboard#index"
    resources :dashboard, only: [:index]
    
    # 통합 회원 관리
    get 'users', to: 'dashboard#users'
    get 'users/content', to: 'dashboard#users_content'
    
    # 동기화 테스트 페이지
    get 'test_sync', to: 'dashboard#test_sync'
    
    # 예약 관리 (통합)
    resources :reservations, only: [:index, :destroy] do
      collection do
        get :content
      end
      member do
        patch :update_status
        patch :approve_reservation
      end
    end
    
    # Practice admin pages (will load content via API)
    get 'practice/users', to: 'dashboard#practice_users'
    patch 'practice/users/:id/approve', to: 'dashboard#approve_practice_user'
    patch 'practice/users/:id/reject', to: 'dashboard#reject_practice_user'
    patch 'practice/users/:id/hold', to: 'dashboard#hold_practice_user'
    patch 'practice/users/:id/reset_penalty', to: 'dashboard#reset_practice_penalty'
    patch 'practice/users/:id/update_teacher', to: 'dashboard#update_practice_teacher'
    patch 'practice/users/:id/reset_password', to: 'dashboard#reset_practice_password'
    patch 'practice/users/:id/update_info', to: 'dashboard#update_practice_user_info'
    get 'practice/penalties', to: 'dashboard#practice_penalties'
    
    # Makeup admin pages (will load content via API)
    get 'makeup/users', to: 'dashboard#makeup_users'
    patch 'makeup/users/:id/approve', to: 'dashboard#approve_makeup_user'
    patch 'makeup/users/:id/reject', to: 'dashboard#reject_makeup_user'
    patch 'makeup/users/:id/hold', to: 'dashboard#hold_makeup_user'
    patch 'makeup/users/:id/reset_penalty', to: 'dashboard#reset_makeup_penalty'
    patch 'makeup/users/:id/update_teacher', to: 'dashboard#update_makeup_teacher'
    patch 'makeup/users/:id/reset_password', to: 'dashboard#reset_makeup_password'
    patch 'makeup/users/:id/update_info', to: 'dashboard#update_makeup_user_info'
    get 'makeup/penalties', to: 'dashboard#makeup_penalties'
  end
  
  # 테스트 컨트롤러
  get 'test/simulate_phone_recovery', to: 'test#simulate_login_with_phone_recovery'
  
  # Phone verification API
  namespace :api do
    post 'send-verification', to: 'phone_verifications#send_code'
    post 'verify-code', to: 'phone_verifications#verify_code'
  end
  
  get "up" => "rails/health#show", as: :rails_health_check
end
