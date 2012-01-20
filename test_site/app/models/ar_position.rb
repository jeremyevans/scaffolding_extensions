class ArPosition < ActiveRecord::Base
  self.table_name = 'positions'
  has_many :employees, :class_name=>'ArEmployee', :foreign_key=>'position_id'

  @scaffold_name = 'position'
  @scaffold_human_name = 'Position'
  @scaffold_select_order = 'name'
end
