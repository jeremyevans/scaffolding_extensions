class CreateMeetingsPositions < Sequel::Migration
  def up
    create_table :meetings_positions do
      foreign_key :meeting_id, :table=>:meetings
      foreign_key :position_id, :table=>:positions
    end
  end

  def down
    drop_table :meetings_positions
  end
end
