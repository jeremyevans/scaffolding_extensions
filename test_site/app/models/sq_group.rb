class SqGroup < Sequel::Model(:groups)
  many_to_many :employees, :class_name=>'SqEmployee', :join_table=>:employees_groups, :left_key=>:group_id, :right_key=>:employee_id

  @scaffold_name = 'group'
  @scaffold_human_name = 'Group'
  @scaffold_select_order = :name
end
