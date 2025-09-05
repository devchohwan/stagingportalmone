class CreatePhoneVerifications < ActiveRecord::Migration[8.0]
  def change
    create_table :phone_verifications do |t|
      t.string :phone
      t.string :code
      t.boolean :verified
      t.datetime :expires_at

      t.timestamps
    end
  end
end
