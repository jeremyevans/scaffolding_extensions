class ActiveRecordController < Ramaze::Controller
  map '/active_record'
  helper :aspect
  after_all{ActiveRecord::Base.clear_active_connections!}
  scaffold ArOfficer
  scaffold ArMeeting
  scaffold_all_models :only=>[ArEmployee, ArGroup, ArPosition]
end

class ASequelController < Ramaze::Controller
  map '/sequel'
  scaffold SqOfficer
  scaffold SqMeeting
  scaffold_all_models :only=>[SqEmployee, SqGroup, SqPosition]
end
