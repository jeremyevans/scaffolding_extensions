class ActiveRecordController < Ramaze::Controller
  map '/active_record'
  scaffold_all_models :only=>[ArEmployee, ArGroup, ArPosition]
end

class DataMapperController < Ramaze::Controller
  map '/data_mapper'
  scaffold_all_models :only=>[DmEmployee, DmGroup, DmPosition]
end
