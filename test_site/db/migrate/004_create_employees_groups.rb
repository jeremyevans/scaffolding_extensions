class CreateEmployeesGroups < ActiveRecord::Migration
  def self.up
    create_table (:employees_groups, :id=>false) do |t|
      t.integer :employee_id
      t.integer :group_id
    end
  end

  def self.down
    drop_table :employees_groups
  end
end
