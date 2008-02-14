class ARPosition < ActiveRecord::Base
  set_table_name 'positions'
  has_many :employees, :class_name=>'AREmployee', :foreign_key=>'position_id'

  @scaffold_name = 'position'
  @scaffold_human_name = 'Position'
end
