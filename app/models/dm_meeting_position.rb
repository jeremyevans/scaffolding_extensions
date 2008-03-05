class DmMeetingPosition < DataMapper::Base
  set_table_name 'meetings_positions'
  belongs_to :meeting, :class_name=>'DmMeeting', :foreign_key=>'meeting_id'
  belongs_to :position, :class_name=>'DmPosition', :foreign_key=>'position_id'
end
