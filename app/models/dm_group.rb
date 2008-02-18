class DmGroup < DataMapper::Base
  property :name, :string

  set_table_name 'groups'
  has_and_belongs_to_many :employees, :class_name=>'DmEmployee', :join_table=>'employees_groups', :left_foreign_key=>'group_id', :right_foreign_key=>'employee_id'

  @scaffold_name = 'group'
  @scaffold_human_name = 'Group'
  @scaffold_select_order = 'name'
end
