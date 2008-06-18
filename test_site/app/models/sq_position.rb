class SqPosition < Sequel::Model(:positions)
  one_to_many :employees, :class_name=>'SqEmployee', :key=>:position_id

  @scaffold_name = 'position'
  @scaffold_human_name = 'Position'
  @scaffold_select_order = :name
end
