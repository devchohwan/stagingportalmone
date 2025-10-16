class AddUserEnrollmentIdToMakeupPassRequests < ActiveRecord::Migration[8.0]
  def change
    add_column :makeup_pass_requests, :user_enrollment_id, :integer
    add_index :makeup_pass_requests, :user_enrollment_id
  end
end
