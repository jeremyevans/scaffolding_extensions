class DatamapperController < ApplicationController
  add_scaffolding_methods [DmOfficer, DmMeeting, DmEmployee, DmGroup, DmPosition]
  scaffold DmOfficer
  scaffold DmMeeting
  scaffold_all_models :only=>[DmEmployee, DmGroup, DmPosition]
end
