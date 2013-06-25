class ArEmployee < ActiveRecord::Base
  self.table_name = 'employees'
  belongs_to :position, :class_name=>'ArPosition', :foreign_key=>'position_id'
  if ActiveRecord.respond_to?(:version) # Rails 4+
    has_and_belongs_to_many :groups, proc{order('name')}, :class_name=>'ArGroup', :join_table=>'employees_groups', :foreign_key=>'employee_id', :association_foreign_key=>'group_id'
  else
    has_and_belongs_to_many :groups, :class_name=>'ArGroup', :join_table=>'employees_groups', :foreign_key=>'employee_id', :association_foreign_key=>'group_id', :order=>'name'
  end


  @scaffold_name = 'employee'
  @scaffold_human_name = 'Employee'
  @scaffold_select_order = 'employees.name'
  @scaffold_include = :position
end
