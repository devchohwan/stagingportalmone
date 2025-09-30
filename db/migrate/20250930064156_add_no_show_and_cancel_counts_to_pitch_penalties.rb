class AddNoShowAndCancelCountsToPitchPenalties < ActiveRecord::Migration[8.0]
  def change
    add_column :pitch_penalties, :no_show_count, :integer, default: 0, null: false
    add_column :pitch_penalties, :cancel_count, :integer, default: 0, null: false

    # 기존 penalty_count 값을 cancel_count로 이동
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE pitch_penalties
          SET cancel_count = penalty_count
          WHERE penalty_count > 0
        SQL
      end
    end
  end
end
