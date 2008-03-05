class DmPosition < DataMapper::Base
  property :name, :string

  set_table_name 'positions'
  has_many :employees, :class_name=>'DmEmployee', :foreign_key=>'position_id'

  @scaffold_name = 'position'
  @scaffold_human_name = 'Position'
  @scaffold_select_order = 'name'
  
  # DATAMAPPER_BUG: need habtm in both classes for it to work
  has_and_belongs_to_many :meetings, :class_name=>'DmMeeting', :join_table=>'meetings_positions', :left_foreign_key=>'position_id', :right_foreign_key=>'meeting_id'
  @scaffold_associations = [:employees]
end
