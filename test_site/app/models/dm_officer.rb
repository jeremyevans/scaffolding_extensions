class DmOfficer
  include DataMapper::Resource
  property :id, Serial
  property :name, String
  property :position_id, Integer

  storage_names[:default] = 'officers'

  belongs_to :position, :model => 'DmPosition', :child_key => [:position_id], :required => false
  has n, :groups, :model => 'DmGroup', :through => Resource

  @scaffold_name = 'officer'
  @scaffold_human_name = 'Officer'
  @scaffold_select_order = 'name'
  @scaffold_use_auto_complete = true
  @scaffold_browse_records_per_page = nil

  def self.scaffold_association_use_auto_complete(association)
    true
  end

end
