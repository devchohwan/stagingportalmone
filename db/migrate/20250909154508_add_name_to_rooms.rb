class AddNameToRooms < ActiveRecord::Migration[8.0]
  def change
    # name 컬럼이 이미 존재하므로 스킵
    unless column_exists?(:rooms, :name)
      add_column :rooms, :name, :string
    end
  end
end
