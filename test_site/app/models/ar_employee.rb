class ArEmployee < ActiveRecord::Base
  set_table_name 'employees'
  belongs_to :position, :class_name=>'ArPosition', :foreign_key=>'position_id'
  has_and_belongs_to_many :groups, :class_name=>'ArGroup', :join_table=>'employees_groups', :foreign_key=>'employee_id', :association_foreign_key=>'group_id', :order=>'name'

  @scaffold_name = 'employee'
  @scaffold_human_name = 'Employee'
  @scaffold_select_order = 'employees.name'
  @scaffold_include = :position
end
