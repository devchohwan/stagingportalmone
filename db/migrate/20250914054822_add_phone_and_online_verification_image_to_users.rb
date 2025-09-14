class AddPhoneAndOnlineVerificationImageToUsers < ActiveRecord::Migration[8.0]
  def change
    # phone 필드가 이미 존재할 수 있으므로 조건부로 추가
    add_column :users, :phone, :string unless column_exists?(:users, :phone)
    add_column :users, :online_verification_image, :string unless column_exists?(:users, :online_verification_image)
  end
end
