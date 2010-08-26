class ActiveRecordController < Ramaze::Controller
  map '/', :ar
  app = Ramaze::App[:ar]
  app.location = '/active_record'
  app.options.views = 'view2'
  app.options.layouts = 'view2'
  scaffold ArOfficer
  scaffold ArMeeting
  scaffold_all_models :only=>[ArEmployee, ArGroup, ArPosition]
end

class SequController < Ramaze::Controller
  map '/', :sq
  app = Ramaze::App[:sq]
  app.location = '/sequel'
  app.options.views = 'view'
  app.options.layouts = 'view'
  layout "default"
  scaffold SqOfficer
  scaffold SqMeeting
  scaffold_all_models :only=>[SqEmployee, SqGroup, SqPosition]
end

class DatamapperController < Ramaze::Controller
  map '/', :dm
  app = Ramaze::App[:dm]
  app.location = '/datamapper'
  add_scaffolding_methods [DmOfficer, DmMeeting, DmEmployee, DmGroup, DmPosition]
  scaffold DmOfficer
  scaffold DmMeeting
  scaffold_all_models :only=>[DmEmployee, DmGroup, DmPosition]
end
