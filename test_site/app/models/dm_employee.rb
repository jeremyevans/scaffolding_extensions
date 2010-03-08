class DmEmployee
  include DataMapper::Resource
  property :id, Serial
  property :name, String
  property :active, Boolean
  property :position_id, Integer, :required => false
  property :comment, Text
  property :password, String

  storage_names[:default] = 'employees'

  belongs_to :position, :model => 'DmPosition', :child_key => [:position_id], :required => false
  has n, :employee_groups, :model => 'DmEmployeeDmGroup', :child_key => [:employee_id]
  has n, :groups, :model => 'DmGroup', :through => :employee_groups

  @scaffold_name = 'employee'
  @scaffold_human_name = 'Employee'
  @scaffold_select_order = 'employees.name'
  @scaffold_include = :position

end
