# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_10_15_051335) do
  create_table "enrollment_schedule_histories", force: :cascade do |t|
    t.integer "user_enrollment_id", null: false
    t.string "day", null: false
    t.string "time_slot", null: false
    t.datetime "changed_at", null: false
    t.date "effective_from", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_enrollment_id", "effective_from"], name: "idx_on_user_enrollment_id_effective_from_27b2de27e8"
    t.index ["user_enrollment_id"], name: "index_enrollment_schedule_histories_on_user_enrollment_id"
  end

  create_table "enrollment_status_histories", force: :cascade do |t|
    t.integer "user_enrollment_id", null: false
    t.string "status", null: false
    t.datetime "changed_at", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_enrollment_id", "changed_at"], name: "idx_on_user_enrollment_id_changed_at_94e3488428"
    t.index ["user_enrollment_id"], name: "index_enrollment_status_histories_on_user_enrollment_id"
  end

  create_table "lesson_deductions", force: :cascade do |t|
    t.integer "user_enrollment_id", null: false
    t.date "deduction_date", null: false
    t.datetime "deduction_time", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_enrollment_id", "deduction_date"], name: "index_lesson_deductions_on_enrollment_and_date", unique: true
  end

  create_table "makeup_availabilities", force: :cascade do |t|
    t.string "teacher_name", null: false
    t.integer "day_of_week"
    t.time "start_time"
    t.time "end_time"
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["teacher_name", "day_of_week"], name: "index_makeup_availabilities_on_teacher_name_and_day_of_week"
    t.index ["teacher_name"], name: "index_makeup_availabilities_on_teacher_name"
  end

  create_table "makeup_lessons", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "teacher_name", null: false
    t.string "subject", null: false
    t.date "missed_date"
    t.text "reason"
    t.datetime "requested_datetime"
    t.datetime "confirmed_datetime"
    t.string "status", default: "pending"
    t.text "admin_note"
    t.string "location"
    t.integer "duration_minutes", default: 60
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["status"], name: "index_makeup_lessons_on_status"
    t.index ["teacher_name"], name: "index_makeup_lessons_on_teacher_name"
    t.index ["user_id", "status"], name: "index_makeup_lessons_on_user_id_and_status"
    t.index ["user_id"], name: "index_makeup_lessons_on_user_id"
  end

  create_table "makeup_pass_requests", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "request_type", null: false
    t.date "request_date", null: false
    t.string "time_slot"
    t.string "teacher"
    t.integer "week_number", null: false
    t.text "content", null: false
    t.string "status", default: "pending"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "makeup_date"
    t.datetime "cancelled_at"
    t.index ["makeup_date"], name: "index_makeup_pass_requests_on_makeup_date"
    t.index ["request_date"], name: "index_makeup_pass_requests_on_request_date"
    t.index ["user_id", "status"], name: "index_makeup_pass_requests_on_user_id_and_status"
    t.index ["user_id"], name: "index_makeup_pass_requests_on_user_id"
  end

  create_table "makeup_quota", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "year", null: false
    t.integer "month", null: false
    t.integer "max_count", default: 0, null: false
    t.integer "used_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "year", "month"], name: "index_makeup_quota_on_user_id_and_year_and_month", unique: true
    t.index ["user_id"], name: "index_makeup_quota_on_user_id"
  end

  create_table "makeup_reservations", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "makeup_room_id", null: false
    t.datetime "start_time", null: false
    t.datetime "end_time", null: false
    t.string "status", default: "pending"
    t.string "cancelled_by"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "lesson_content"
    t.text "cancellation_reason"
    t.integer "week_number"
    t.index ["makeup_room_id", "start_time"], name: "index_makeup_reservations_on_makeup_room_id_and_start_time"
    t.index ["makeup_room_id"], name: "index_makeup_reservations_on_makeup_room_id"
    t.index ["start_time", "end_time"], name: "index_makeup_reservations_on_start_time_and_end_time"
    t.index ["status"], name: "index_makeup_reservations_on_status"
    t.index ["user_id", "start_time"], name: "index_makeup_reservations_on_user_id_and_start_time"
    t.index ["user_id", "status"], name: "index_makeup_reservations_on_user_id_and_status"
    t.index ["user_id"], name: "index_makeup_reservations_on_user_id"
  end

  create_table "makeup_rooms", force: :cascade do |t|
    t.string "name", null: false
    t.integer "number", null: false
    t.text "description"
    t.boolean "has_outlet", default: false
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["is_active"], name: "index_makeup_rooms_on_is_active"
    t.index ["number"], name: "index_makeup_rooms_on_number", unique: true
  end

  create_table "payments", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "subject"
    t.integer "period"
    t.integer "amount"
    t.integer "lessons"
    t.date "payment_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "first_lesson_date"
    t.string "first_lesson_time"
    t.integer "enrollment_id"
    t.json "discount_items"
    t.integer "discount_amount"
    t.integer "final_amount"
    t.string "teacher"
    t.integer "months"
    t.string "discounts"
    t.index ["user_id"], name: "index_payments_on_user_id"
  end

  create_table "penalties", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "month"
    t.integer "year"
    t.integer "no_show_count"
    t.integer "cancel_count"
    t.boolean "is_blocked"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "system_type", default: "practice", null: false
    t.index ["user_id", "year", "month", "system_type"], name: "index_penalties_on_user_year_month_system", unique: true
    t.index ["user_id"], name: "index_penalties_on_user_id"
  end

  create_table "phone_verifications", force: :cascade do |t|
    t.string "phone"
    t.string "code"
    t.boolean "verified"
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_phone_verifications_on_expires_at"
    t.index ["phone"], name: "index_phone_verifications_on_phone"
  end

  create_table "pitch_penalties", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "penalty_count", default: 0, null: false
    t.integer "month", null: false
    t.integer "year", null: false
    t.boolean "is_blocked", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "no_show_count", default: 0, null: false
    t.integer "cancel_count", default: 0, null: false
    t.index ["user_id", "month", "year"], name: "index_pitch_penalties_on_user_id_and_month_and_year", unique: true
    t.index ["user_id"], name: "index_pitch_penalties_on_user_id"
  end

  create_table "pitch_reservations", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "pitch_room_id", null: false
    t.datetime "start_time", null: false
    t.datetime "end_time", null: false
    t.string "status", default: "pending"
    t.datetime "approved_at"
    t.string "approved_by"
    t.string "cancelled_by"
    t.datetime "cancelled_at"
    t.text "cancellation_reason"
    t.text "notes"
    t.text "admin_note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "week_number"
    t.index ["pitch_room_id", "start_time"], name: "index_pitch_reservations_on_pitch_room_id_and_start_time"
    t.index ["pitch_room_id"], name: "index_pitch_reservations_on_pitch_room_id"
    t.index ["start_time", "end_time"], name: "index_pitch_reservations_on_start_time_and_end_time"
    t.index ["status"], name: "index_pitch_reservations_on_status"
    t.index ["user_id", "start_time"], name: "index_pitch_reservations_on_user_id_and_start_time"
    t.index ["user_id", "status"], name: "index_pitch_reservations_on_user_id_and_status"
    t.index ["user_id"], name: "index_pitch_reservations_on_user_id"
  end

  create_table "pitch_rooms", force: :cascade do |t|
    t.string "name", null: false
    t.integer "seat_number", null: false
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["is_active"], name: "index_pitch_rooms_on_is_active"
    t.index ["seat_number"], name: "index_pitch_rooms_on_seat_number", unique: true
  end

  create_table "reservations", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "room_id", null: false
    t.datetime "start_time"
    t.datetime "end_time"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "cancelled_by"
    t.text "cancellation_reason"
    t.index ["room_id", "start_time"], name: "index_reservations_on_room_id_and_start_time"
    t.index ["room_id"], name: "index_reservations_on_room_id"
    t.index ["status"], name: "index_reservations_on_status"
    t.index ["user_id", "start_time"], name: "index_reservations_on_user_id_and_start_time"
    t.index ["user_id"], name: "index_reservations_on_user_id"
  end

  create_table "rooms", force: :cascade do |t|
    t.string "name"
    t.integer "capacity"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "number"
    t.boolean "has_outlet"
    t.index ["number"], name: "index_rooms_on_number", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.string "session_id", null: false
    t.text "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["session_id"], name: "index_sessions_on_session_id", unique: true
    t.index ["updated_at"], name: "index_sessions_on_updated_at"
  end

  create_table "teacher_schedules", force: :cascade do |t|
    t.string "teacher", null: false
    t.string "day", null: false
    t.string "time_slot", null: false
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "end_date"
    t.boolean "is_absent", default: false, null: false
    t.date "start_date"
    t.index ["teacher", "day", "time_slot", "user_id"], name: "index_teacher_schedules_unique", unique: true
    t.index ["user_id"], name: "index_teacher_schedules_on_user_id"
  end

  create_table "user_enrollments", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "teacher"
    t.string "subject"
    t.string "day"
    t.string "time_slot"
    t.integer "remaining_lessons", default: 0
    t.date "first_lesson_date"
    t.date "end_date"
    t.string "status", default: "active"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "is_paid", default: false
    t.text "teacher_history"
    t.index ["user_id", "teacher", "subject"], name: "index_user_enrollments_on_user_id_and_teacher_and_subject"
    t.index ["user_id"], name: "index_user_enrollments_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "username", null: false
    t.string "name", null: false
    t.string "email"
    t.string "phone"
    t.string "password_digest", null: false
    t.string "status", default: "pending"
    t.boolean "is_admin", default: false
    t.string "teacher"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "online_verification_image"
    t.integer "remaining_lessons"
    t.date "last_payment_date"
    t.integer "remaining_passes", default: 0, null: false
    t.date "passes_expire_date"
    t.date "first_lesson_date"
    t.index ["email"], name: "index_users_on_email"
    t.index ["status"], name: "index_users_on_status"
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "enrollment_schedule_histories", "user_enrollments"
  add_foreign_key "enrollment_status_histories", "user_enrollments"
  add_foreign_key "makeup_lessons", "users"
  add_foreign_key "makeup_pass_requests", "users"
  add_foreign_key "makeup_quota", "users"
  add_foreign_key "makeup_reservations", "makeup_rooms"
  add_foreign_key "makeup_reservations", "users"
  add_foreign_key "payments", "users"
  add_foreign_key "penalties", "users"
  add_foreign_key "pitch_penalties", "users"
  add_foreign_key "pitch_reservations", "pitch_rooms"
  add_foreign_key "pitch_reservations", "users"
  add_foreign_key "reservations", "rooms"
  add_foreign_key "reservations", "users"
  add_foreign_key "user_enrollments", "users"
end
