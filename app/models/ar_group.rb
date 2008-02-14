class ARGroup < ActiveRecord::Base
  set_table_name 'groups'
  has_and_belongs_to_many :employees, :class_name=>'AREmployee', :join_table=>'employees_groups', :foreign_key=>'group_id', :association_foreign_key=>'employee_id'

  @scaffold_name = 'group'
  @scaffold_human_name = 'Group'
end
