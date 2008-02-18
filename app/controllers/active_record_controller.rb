class ActiveRecordController < ApplicationController
  scaffold_all_models :only=>[ArEmployee, ArGroup, ArPosition]
end
