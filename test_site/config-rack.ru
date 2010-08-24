#!/usr/local/bin/ruby
require 'rubygems'
SE_TEST_FRAMEWORK='rack'
require 'rack'
require 'rack/builder'
require 'ar_garbage'
require 'datamapper_setup'
require 'active_record_setup'
require 'sequel_setup'
require 'se_setup'
require 'scaffolding_extensions/controller/rack'

class SequelRack < ScaffoldingExtensions::RackController
  scaffold SqOfficer
  scaffold SqMeeting
  scaffold_all_models :only=>[SqEmployee, SqGroup, SqPosition]
end

class ActiveRecordRack < ScaffoldingExtensions::RackController
  scaffold ArOfficer
  scaffold ArMeeting
  scaffold_all_models :only=>[ArEmployee, ArGroup, ArPosition]
end

class DatamapperRack < ScaffoldingExtensions::RackController
  add_scaffolding_methods [DmOfficer, DmMeeting, DmEmployee, DmGroup, DmPosition]
  scaffold DmOfficer
  scaffold DmMeeting
  scaffold_all_models :only=>[DmEmployee, DmGroup, DmPosition]
end

app = Rack::Builder.app do
  use Rack::CommonLogger
  use Rack::Lint
  map "/sequel" do
    run SequelRack
  end
  map "/active_record" do
    use CleanUpARGarbage
    run ActiveRecordRack
  end
  map "/datamapper" do
    run DatamapperRack
  end
end
run app
