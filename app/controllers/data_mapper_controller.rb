class DataMapperController < ApplicationController
  scaffold DmOfficer
  scaffold_all_models :only=>[DmEmployee, DmGroup, DmPosition]
end
