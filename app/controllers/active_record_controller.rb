class ActiveRecordController < ApplicationController
  scaffold_all_models :only=>[AREmployee, ARGroup, ARPosition]
end
