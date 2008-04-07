class ActiveRecordController < ApplicationController
  scaffold ArOfficer
  scaffold ArMeeting
  scaffold_all_models :only=>[ArEmployee, ArGroup, ArPosition]
end
