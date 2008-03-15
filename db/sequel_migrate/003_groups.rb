class CreateGroups < Sequel::Migration
  def up
    create_table :groups do
      primary_key :id
      varchar :name, :size=>255
    end
  end

  def down
    drop_table :groups
  end
end
