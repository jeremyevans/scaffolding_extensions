class CreateEmployeesGroups < Sequel::Migration
  def up
    create_table :employees_groups do
      foreign_key :employee_id, :table=>:employees
      foreign_key :group_id, :table=>:groups
    end
  end

  def down
    drop_table :employees_groups
  end
end
