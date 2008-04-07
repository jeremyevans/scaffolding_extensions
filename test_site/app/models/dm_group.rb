class DmGroup < DataMapper::Base
  property :name, :string

  set_table_name 'groups'
  has_and_belongs_to_many :employees, :class_name=>'DmEmployee', :join_table=>'employees_groups', :left_foreign_key=>'group_id', :right_foreign_key=>'employee_id'
  
  @scaffold_name = 'group'
  @scaffold_human_name = 'Group'
  @scaffold_select_order = 'name'
  
  # DATAMAPPER_BUG: need habtm in both classes for it to work
  has_and_belongs_to_many :meetings, :class_name=>'DmMeeting', :join_table=>'groups_meetings', :left_foreign_key=>'group_id', :right_foreign_key=>'meeting_id'
  @scaffold_associations = [:employees]
end
