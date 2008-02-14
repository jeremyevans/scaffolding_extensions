class ActiveRecordController < Ramaze::Controller
  map '/active_record'
  scaffold_all_models :only=>[AREmployee, ARGroup, ARPosition]
end
