class AREmployee < ActiveRecord::Base
  set_table_name 'employees'
  belongs_to :position, :class_name=>'ARPosition', :foreign_key=>'position_id'
  has_and_belongs_to_many :groups, :class_name=>'ARGroup', :join_table=>'employees_groups', :foreign_key=>'employee_id', :association_foreign_key=>'group_id'

  @scaffold_name = 'employee'
  @scaffold_human_name = 'Employee'
end
