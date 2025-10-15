class CreateEnrollmentScheduleHistories < ActiveRecord::Migration[8.0]
  def change
    create_table :enrollment_schedule_histories do |t|
      t.references :user_enrollment, null: false, foreign_key: true
      t.string :day, null: false
      t.string :time_slot, null: false
      t.datetime :changed_at, null: false
      t.date :effective_from, null: false

      t.timestamps
    end

    add_index :enrollment_schedule_histories, [:user_enrollment_id, :effective_from]
  end
end
