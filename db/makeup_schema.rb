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

ActiveRecord::Schema[8.0].define(version: 2025_09_05_093850) do
  create_table "makeup_reservations", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "teacher"
    t.string "subject"
    t.date "date"
    t.string "time"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_makeup_reservations_on_user_id"
  end

  create_table "penalties", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "month", null: false
    t.integer "year", null: false
    t.integer "penalty_count", default: 0
    t.integer "no_show_count", default: 0
    t.integer "cancel_count", default: 0
    t.boolean "is_blocked", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "month", "year"], name: "index_penalties_on_user_id_and_month_and_year", unique: true
    t.index ["user_id"], name: "index_penalties_on_user_id"
  end

  create_table "phone_verifications", force: :cascade do |t|
    t.string "phone"
    t.string "code"
    t.boolean "verified"
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "reservations", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "room_id", null: false
    t.datetime "start_time", null: false
    t.datetime "end_time", null: false
    t.string "status", default: "pending"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "cancelled_by"
    t.index ["room_id", "start_time", "end_time"], name: "index_reservations_on_room_id_and_start_time_and_end_time"
    t.index ["room_id"], name: "index_reservations_on_room_id"
    t.index ["status"], name: "index_reservations_on_status"
    t.index ["user_id"], name: "index_reservations_on_user_id"
  end

  create_table "rooms", force: :cascade do |t|
    t.integer "number", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["number"], name: "index_rooms_on_number", unique: true
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
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "makeup_reservations", "users"
  add_foreign_key "penalties", "users"
  add_foreign_key "reservations", "rooms"
  add_foreign_key "reservations", "users"
end
