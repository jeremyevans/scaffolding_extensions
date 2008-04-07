class CreateGroupsMeetings < ActiveRecord::Migration
  def self.up
    create_table (:groups_meetings, :id=>false) do |t|
      t.integer :group_id
      t.integer :meeting_id
    end
  end

  def self.down
    drop_table :groups_meetings
  end
end
