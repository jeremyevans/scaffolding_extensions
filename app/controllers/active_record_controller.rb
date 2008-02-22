class ActiveRecordController < ApplicationController
  scaffold ArOfficer
  scaffold_all_models :only=>[ArEmployee, ArGroup, ArPosition]
end
