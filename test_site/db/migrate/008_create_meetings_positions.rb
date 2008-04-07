class CreateMeetingsPositions < ActiveRecord::Migration
  def self.up
    create_table (:meetings_positions, :id=>false) do |t|
      t.integer :meeting_id
      t.integer :position_id
    end
  end

  def self.down
    drop_table :meetings_positions
  end
end
