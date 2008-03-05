class DmGroupMeeting < DataMapper::Base
  set_table_name 'groups_meetings'
  belongs_to :meeting, :class_name=>'DmMeeting', :foreign_key=>'meeting_id'
  belongs_to :group, :class_name=>'DmGroup', :foreign_key=>'group_id'
end
