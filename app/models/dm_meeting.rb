class DmMeeting < DataMapper::Base
  property :name, :string

  set_table_name 'meetings'
  has_and_belongs_to_many :groups, :class_name=>'DmGroup', :join_table=>'groups_meetings', :left_foreign_key=>'meeting_id', :right_foreign_key=>'group_id', :order=>'name'
  has_and_belongs_to_many :positions, :class_name=>'DmPosition', :join_table=>'meetings_positions', :left_foreign_key=>'meeting_id', :right_foreign_key=>'position_id'

  @scaffold_name = 'meeting'
  @scaffold_human_name = 'Meeting'
  @scaffold_select_order = 'name'
  @scaffold_positions_association_use_auto_complete = true
  @scaffold_load_associations_with_ajax = true
  @scaffold_habtm_with_ajax = true
end
