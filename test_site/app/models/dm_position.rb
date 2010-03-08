class DmPosition
  include DataMapper::Resource
  property :id, Serial
  property :name, String

  storage_names[:default] = 'positions'

  has n, :employees, :model => 'DmEmployee', :child_key => [:position_id]

  @scaffold_name = 'position'
  @scaffold_human_name = 'Position'
  @scaffold_select_order = 'name'

end
