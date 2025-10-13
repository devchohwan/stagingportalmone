class CreateUserEnrollments < ActiveRecord::Migration[8.0]
  def change
    create_table :user_enrollments do |t|
      t.references :user, null: false, foreign_key: true
      t.string :teacher
      t.string :subject
      t.string :day
      t.string :time_slot
      t.integer :remaining_lessons, default: 0
      t.date :first_lesson_date
      t.date :end_date
      t.string :status, default: 'active'

      t.timestamps
    end

    add_index :user_enrollments, [:user_id, :teacher, :subject]
  end
end
