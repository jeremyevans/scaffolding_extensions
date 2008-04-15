#!/usr/local/bin/ruby
require 'rubygems'
SE_TEST_FRAMEWORK='sinatra'
require 'active_record_setup'
require 'data_mapper_setup'
require 'sequel_setup'

require 'sinatra'
app = Sinatra.application
app.options.env = :production

def app.reload!
  nil
end

require 'se_setup'

scaffold('/active_record', ArOfficer)
scaffold('/active_record', ArMeeting)
scaffold_all_models('/active_record', :only=>[ArEmployee, ArGroup, ArPosition])
scaffold('/data_mapper', DmOfficer)
scaffold('/data_mapper', DmMeeting)
scaffold_all_models('/data_mapper', :only=>[DmEmployee, DmGroup, DmPosition])
scaffold('/sequel', SqOfficer)
scaffold('/sequel', SqMeeting)
scaffold_all_models('/sequel', :only=>[SqEmployee, SqGroup, SqPosition])
