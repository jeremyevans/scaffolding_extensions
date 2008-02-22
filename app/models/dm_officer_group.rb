class DmOfficerGroup < DataMapper::Base
  set_table_name 'groups_officers'
  belongs_to :employee, :class_name=>'DmOfficer', :foreign_key=>'officer_id'
  belongs_to :group, :class_name=>'DmGroup', :foreign_key=>'group_id'
end
