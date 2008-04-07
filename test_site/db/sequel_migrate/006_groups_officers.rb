class CreateGroupsOfficers < Sequel::Migration
  def up
    create_table :groups_officers do
      foreign_key :officer_id, :table=>:officers
      foreign_key :group_id, :table=>:groups
    end
  end

  def down
    drop_table :groups_officers
  end
end
