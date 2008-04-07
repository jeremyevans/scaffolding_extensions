class CreateEmployees < Sequel::Migration
  def up
    create_table :employees do
      primary_key :id
      varchar :name, :size=>255
      boolean :active
      foreign_key :position_id, :table=>:positions
      text :comment
      varchar :password, :size=>255
    end
  end

  def down
    drop_table :employees
  end
end
