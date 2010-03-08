# datamapper's has n, :through => Resource breaks when the storage names != model names
# the only fix I found is to drop using anonymous tables and define them separately :(

class DmEmployeeDmGroup
  include DataMapper::Resource

  storage_names[:default] = 'dm_employee_dm_groups'

  property :employee_id, Integer, :key => true
  property :group_id, Integer, :key => true

  belongs_to :employee, :model => 'DmEmployee', :child_key => [:employee_id]
  belongs_to :group, :model => 'DmGroup', :child_key => [:group_id]
end
