class AddPhoneAndOnlineVerificationImageToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :phone, :string
    add_column :users, :online_verification_image, :string
  end
end
