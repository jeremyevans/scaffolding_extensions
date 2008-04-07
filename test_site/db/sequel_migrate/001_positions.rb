class CreatePositions < Sequel::Migration
  def up
    create_table :positions do
      primary_key :id
      varchar :name, :size=>255
    end
  end

  def down
    drop_table :positions
  end
end
