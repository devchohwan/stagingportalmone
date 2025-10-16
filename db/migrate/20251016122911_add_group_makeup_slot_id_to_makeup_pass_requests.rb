class AddGroupMakeupSlotIdToMakeupPassRequests < ActiveRecord::Migration[8.0]
  def change
    add_reference :makeup_pass_requests, :group_makeup_slot, null: true, foreign_key: true
  end
end
