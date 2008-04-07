class CreateOfficers < Sequel::Migration
  def up
    create_table :officers do
      primary_key :id
      varchar :name, :size=>255
      foreign_key :position_id, :table=>:positions
    end
  end

  def down
    drop_table :officers
  end
end
