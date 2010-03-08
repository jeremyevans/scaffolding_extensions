class DmMeeting
  include DataMapper::Resource

  property :id, Serial
  property :name, String

  storage_names[:default] = 'meetings'
  has n, :groups, :model => 'DmGroup', :through => Resource
  has n, :positions, :model => 'DmPosition', :through => Resource

  @scaffold_name = 'meeting'
  @scaffold_human_name = 'Meeting'
  @scaffold_select_order = 'name'
  @scaffold_positions_association_use_auto_complete = true
  @scaffold_load_associations_with_ajax = true
  @scaffold_habtm_with_ajax = true

end
