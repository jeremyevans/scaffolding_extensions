class SqMeeting < Sequel::Model(:meetings)
  many_to_many :positions, :class_name=>'SqPosition', :join_table=>:meetings_positions, :left_key=>:meeting_id, :right_key=>:position_id
  many_to_many :groups, :class_name=>'SqGroup', :join_table=>:groups_meetings, :left_key=>:meeting_id, :right_key=>:group_id

  @scaffold_name = 'meeting'
  @scaffold_human_name = 'Meeting'
  @scaffold_select_order = :name
  @scaffold_positions_association_use_auto_complete = true
  @scaffold_load_associations_with_ajax = true
  @scaffold_habtm_with_ajax = true
end
