class CreateGroupsMeetings < Sequel::Migration
  def up
    create_table :groups_meetings do
      foreign_key :meeting_id, :table=>:meetings
      foreign_key :group_id, :table=>:groups
    end
  end

  def down
    drop_table :groups_meetings
  end
end
