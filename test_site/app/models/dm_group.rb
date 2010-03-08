class DmGroup
  include DataMapper::Resource
  property :id, Serial
  property :name, String

  storage_names[:default] = 'groups'
  has n, :employee_groups, :model => 'DmEmployeeDmGroup', :child_key => [:group_id]
  has n, :employees, :model => 'DmEmployee', :through => :employee_groups

  @scaffold_name = 'group'
  @scaffold_human_name = 'Group'
  @scaffold_select_order = 'name'

end
