class AddRemainingPassesToUserEnrollments < ActiveRecord::Migration[8.0]
  def change
    add_column :user_enrollments, :remaining_passes, :integer, default: 0, null: false
  end
end
