class ArOfficer < ActiveRecord::Base
  set_table_name 'officers'
  belongs_to :position, :class_name=>'ArPosition', :foreign_key=>'position_id'
  has_and_belongs_to_many :groups, :class_name=>'ArGroup', :join_table=>'groups_officers', :foreign_key=>'officer_id', :association_foreign_key=>'group_id'

  @scaffold_name = 'officer'
  @scaffold_human_name = 'Officer'
  @scaffold_select_order = 'name'
  @scaffold_use_auto_complete = true
  @scaffold_browse_records_per_page = nil
  
  def self.scaffold_association_use_auto_complete(association)
    true
  end
end
