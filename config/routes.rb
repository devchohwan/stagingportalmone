Rails.application.routes.draw do
  # Health check endpoint for Kamal
  get "up", to: proc { [200, {}, ["OK"]] }
  
  root "services#index"  # 메인 페이지를 services로 변경
  
  get "login", to: "sessions#new"
  post "login", to: "sessions#create"
  get "logout", to: "sessions#destroy"
  delete "logout", to: "sessions#destroy"
  
  get "register", to: "registrations#new"
  post "register", to: "registrations#create"
  
  get "services", to: "services#index"
  
  # 연습실 페이지
  get "practice", to: "practice#index"
  get "practice/reserve", to: "practice#reserve"
  post "practice/reservations", to: "practice#create_reservation"
  get "practice/my_reservations", to: "practice#my_reservations"
  patch "practice/reservations/:id/cancel", to: "practice#cancel_reservation", as: :cancel_practice_reservation
  get "practice/reservations/:id/change", to: "practice#change_reservation", as: :change_practice_reservation
  patch "practice/reservations/:id/update", to: "practice#update_reservation", as: :update_practice_reservation
  
  # 예약 관련 partial views
  get "practice/calendar", to: "practice#calendar"
  get "practice/time_slots", to: "practice#time_slots"
  get "practice/available_rooms", to: "practice#available_rooms"
  
  # 보충수업 페이지
  get "makeup", to: "makeup#index"
  get "makeup/new", to: "makeup#new"
  post "makeup", to: "makeup#create"
  get "makeup/my_lessons", to: "makeup#my_lessons"

  # 보충수업 예약 관련 partial views - MUST be before :id routes
  get "makeup/calendar", to: "makeup#calendar"
  get "makeup/time_slots", to: "makeup#time_slots"
  get "makeup/available_rooms", to: "makeup#available_rooms"

  # Dynamic routes MUST be last
  get "makeup/:id", to: "makeup#show", as: :makeup_lesson
  patch "makeup/:id/cancel", to: "makeup#cancel", as: :cancel_makeup_lesson

  # 음정수업 페이지
  get "pitch", to: "pitch#index"
  get "pitch/reserve", to: "pitch#reserve"
  post "pitch/reservations", to: "pitch#create_reservation"
  get "pitch/my_reservations", to: "pitch#my_reservations"
  patch "pitch/reservations/:id/cancel", to: "pitch#cancel_reservation", as: :cancel_pitch_reservation

  # 음정수업 관련 partial views
  get "pitch/calendar", to: "pitch#calendar"
  get "pitch/time_slots", to: "pitch#time_slots"
  get "pitch/available_seats", to: "pitch#available_seats"
  
  get "profile/edit", to: "profile#edit", as: :edit_profile
  patch "profile/update_password", to: "profile#update_password", as: :update_password
  patch "profile/update_phone", to: "profile#update_phone", as: :update_phone
  
  get "password_reset", to: "password_resets#new"
  post "password_reset", to: "password_resets#create"
  get "password_reset/edit", to: "password_resets#edit", as: :password_reset_edit
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
        post :bulk_delete
      end
      member do
        patch :update_status
        patch :approve_reservation
        get :lesson_content
        get :makeup_cancellation_reason
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

    # Pitch admin pages
    get 'pitch/reservations', to: 'dashboard#pitch_reservations'
    patch 'pitch/reservations/:id/approve', to: 'dashboard#approve_pitch_reservation'
    patch 'pitch/reservations/:id/reject', to: 'dashboard#reject_pitch_reservation'
    get 'pitch/penalties', to: 'dashboard#pitch_penalties'
    patch 'pitch/penalties/:id/reset', to: 'dashboard#reset_pitch_penalty', as: 'reset_pitch_penalty'
    
    # Penalties management
    resources :penalties, only: [:index] do
      member do
        post :reset
      end
    end
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
