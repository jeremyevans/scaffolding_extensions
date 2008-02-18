class DmEmployee < DataMapper::Base
  property :name, :string
  property :active, :boolean
  property :comment, :text
  property :password, :string

  set_table_name 'employees'
  belongs_to :position, :class_name=>'DmPosition', :foreign_key=>'position_id'
  has_and_belongs_to_many :groups, :class_name=>'DmGroup', :join_table=>'employees_groups', :left_foreign_key=>'employee_id', :right_foreign_key=>'group_id'

  @scaffold_name = 'employee'
  @scaffold_human_name = 'Employee'
  @scaffold_select_order = 'name'
end
