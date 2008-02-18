class DataMapperController < ApplicationController
  scaffold_all_models :only=>[DmEmployee, DmGroup, DmPosition]
end
