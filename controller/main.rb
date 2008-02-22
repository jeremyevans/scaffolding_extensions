class ActiveRecordController < Ramaze::Controller
  map '/active_record'
  scaffold ArOfficer
  scaffold_all_models :only=>[ArEmployee, ArGroup, ArPosition]
end

class DataMapperController < Ramaze::Controller
  map '/data_mapper'
  scaffold DmOfficer
  scaffold_all_models :only=>[DmEmployee, DmGroup, DmPosition]
end
