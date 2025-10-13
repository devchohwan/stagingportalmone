class CreateMakeupPassRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :makeup_pass_requests do |t|
      t.references :user, null: false, foreign_key: true
      t.string :request_type, null: false  # 'makeup' or 'pass'
      t.date :request_date, null: false
      t.string :time_slot  # 보강일 경우만 (예: '14-15')
      t.string :teacher  # 보강일 경우만
      t.integer :week_number, null: false
      t.text :content, null: false
      t.string :status, default: 'pending'  # 'pending', 'approved', 'rejected'

      t.timestamps
    end

    add_index :makeup_pass_requests, [:user_id, :status]
    add_index :makeup_pass_requests, :request_date
  end
end
