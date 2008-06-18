class SqOfficer < Sequel::Model(:officers)
  many_to_one :position, :class_name=>'SqPosition', :key=>:position_id
  many_to_many :groups, :class_name=>'SqGroup', :join_table=>:groups_officers, :left_key=>:officer_id, :right_key=>:group_id

  @scaffold_name = 'officer'
  @scaffold_human_name = 'Officer'
  @scaffold_select_order = :name
  @scaffold_use_auto_complete = true
  @scaffold_browse_records_per_page = nil
  
  def self.scaffold_association_use_auto_complete(association)
    true
  end
end
