class DmPosition < DataMapper::Base
  property :name, :string

  set_table_name 'positions'
  has_many :employees, :class_name=>'DmEmployee', :foreign_key=>'position_id'

  @scaffold_name = 'position'
  @scaffold_human_name = 'Position'
  @scaffold_select_order = 'name'
end
