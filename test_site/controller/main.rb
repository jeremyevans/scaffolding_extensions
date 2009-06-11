class ActiveRecordController < Ramaze::Controller
  map '/active_record'
  scaffold ArOfficer
  scaffold ArMeeting
  scaffold_all_models :only=>[ArEmployee, ArGroup, ArPosition]
end

class SequelController < Ramaze::Controller
  map '/sequel'
  scaffold SqOfficer
  scaffold SqMeeting
  scaffold_all_models :only=>[SqEmployee, SqGroup, SqPosition]
end
