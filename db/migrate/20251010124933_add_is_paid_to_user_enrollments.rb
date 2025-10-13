class AddIsPaidToUserEnrollments < ActiveRecord::Migration[8.0]
  def change
    add_column :user_enrollments, :is_paid, :boolean, default: false
  end
end
