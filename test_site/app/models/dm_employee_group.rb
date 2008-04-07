class DmEmployeeGroup < DataMapper::Base
  set_table_name 'employees_groups'
  belongs_to :employee, :class_name=>'DmEmployee', :foreign_key=>'employee_id'
  belongs_to :group, :class_name=>'DmGroup', :foreign_key=>'group_id'
end
