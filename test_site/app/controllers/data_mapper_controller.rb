class DataMapperController < ApplicationController
  scaffold DmOfficer
  scaffold DmMeeting
  scaffold_all_models :only=>[DmEmployee, DmGroup, DmPosition]
end
