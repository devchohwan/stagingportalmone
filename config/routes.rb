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

  # 보강/패스 신청 페이지
  get "makeup_pass", to: "makeup_pass#index"
  get "makeup_pass/reserve", to: "makeup_pass#reserve"
  post "makeup_pass/reserve", to: "makeup_pass#create_request"
  get "makeup_pass/my_requests", to: "makeup_pass#my_requests"
  get "makeup_pass/requests/:id/change", to: "makeup_pass#change_request", as: :change_makeup_pass_request
  patch "makeup_pass/requests/:id/update", to: "makeup_pass#update_request", as: :update_makeup_pass_request
  patch "makeup_pass/requests/:id/cancel", to: "makeup_pass#cancel_request", as: :cancel_makeup_pass_request

  # 보강/패스 관련 partial views
  get "makeup_pass/calendar", to: "makeup_pass#calendar"
  get "makeup_pass/available_time_slots", to: "makeup_pass#available_time_slots"
  get "makeup_pass/available_teachers", to: "makeup_pass#available_teachers"

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
    patch 'users/:id/update_status', to: 'dashboard#update_user_status'
    patch 'users/:id/toggle_all_enrollments', to: 'dashboard#toggle_all_enrollments'
    patch 'users/:id/toggle_all_enrollments_auto', to: 'dashboard#toggle_all_enrollments_auto'

    # 결제 관리
    get 'payments/content', to: 'dashboard#payments_content'
    get 'payments/calendar_data', to: 'dashboard#payment_calendar_data'
    post 'payments', to: 'dashboard#create_payment'
    get 'payments/user_enrollments/:user_id', to: 'dashboard#user_enrollments'
    get 'payment_calendar', to: 'dashboard#payment_calendar'

    # 결제 시스템 API
    get 'users/:id', to: 'dashboard#get_user'
    post 'process_payment', to: 'dashboard#process_payment'
    get 'payment_history/:user_id', to: 'dashboard#payment_history'

    # 수강 등록 관리
    post 'user_enrollments', to: 'dashboard#create_user_enrollment'
    delete 'user_enrollments/:id', to: 'dashboard#delete_user_enrollment'
    patch 'user_enrollments/:id/toggle_status', to: 'dashboard#toggle_enrollment_status'
    get 'teacher_available_slots', to: 'dashboard#teacher_available_slots'

    # 수강생 검색 API
    get 'search_students', to: 'dashboard#search_students'

    # 스케줄 관리 API
    post 'save_schedule', to: 'dashboard#save_schedule'
    get 'load_schedule', to: 'dashboard#load_schedule'
    get 'schedule_changes', to: 'dashboard#schedule_changes'

    # 보강/패스 관리 API
    get 'makeup_pass_requests', to: 'dashboard#makeup_pass_requests'
    get 'makeup_request_info/:id', to: 'dashboard#makeup_request_info'
    patch 'makeup_pass_requests/:id/approve', to: 'dashboard#approve_makeup_pass_request'
    patch 'makeup_pass_requests/:id/reject', to: 'dashboard#reject_makeup_pass_request'
    delete 'makeup_pass_requests/:id', to: 'dashboard#delete_makeup_pass_request'

    # 시간표 관리
    get 'schedule_manager', to: 'dashboard#schedule_manager'
    get 'schedule_viewer', to: 'dashboard#schedule_viewer'
    get 'schedule_viewer_content', to: 'dashboard#schedule_viewer_content'
    get 'schedule_manager_content', to: 'dashboard#schedule_manager_content'
    get 'payments_content', to: 'dashboard#payments_content'

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
