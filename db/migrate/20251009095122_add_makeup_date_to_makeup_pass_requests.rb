class AddMakeupDateToMakeupPassRequests < ActiveRecord::Migration[8.0]
  def change
    add_column :makeup_pass_requests, :makeup_date, :date, comment: '보강 받을 날짜 (makeup인 경우만)'
    add_index :makeup_pass_requests, :makeup_date
  end
end
