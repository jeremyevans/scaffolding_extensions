class CreateGroupsOfficers < ActiveRecord::Migration
  def self.up
    create_table (:groups_officers, :id=>false) do |t|
      t.integer :group_id
      t.integer :officer_id
    end
  end

  def self.down
    drop_table :groups_officers
  end
end
