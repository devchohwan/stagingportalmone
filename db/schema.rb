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

ActiveRecord::Schema[8.0].define(version: 2025_09_10_085318) do
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

  create_table "makeup_quotas", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "year"
    t.integer "month"
    t.integer "used_count", default: 0
    t.integer "max_count", default: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "year", "month"], name: "index_makeup_quotas_on_user_id_and_year_and_month", unique: true
    t.index ["user_id"], name: "index_makeup_quotas_on_user_id"
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

  create_table "penalties", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "month"
    t.integer "year"
    t.integer "no_show_count"
    t.integer "cancel_count"
    t.boolean "is_blocked"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "year", "month"], name: "index_penalties_on_user_id_and_year_and_month", unique: true
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

  create_table "reservations", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "room_id", null: false
    t.datetime "start_time"
    t.datetime "end_time"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "cancelled_by"
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
    t.index ["email"], name: "index_users_on_email"
    t.index ["status"], name: "index_users_on_status"
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "makeup_lessons", "users"
  add_foreign_key "makeup_quotas", "users"
  add_foreign_key "makeup_reservations", "makeup_rooms"
  add_foreign_key "makeup_reservations", "users"
  add_foreign_key "penalties", "users"
  add_foreign_key "reservations", "rooms"
  add_foreign_key "reservations", "users"
end
