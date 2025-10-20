class AddTeacherColumnsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :teacher_name, :string
    add_column :users, :sms_enabled, :boolean, default: true
  end
end
