#!/usr/local/bin/ruby
require 'rubygems'
SE_TEST_FRAMEWORK='sinatra'
require 'sinatra'
set(:port=>7976, :host=>'0.0.0.0', :env=>:production, :app_file=>'sinatra_se', :raise_errors=>true, :logging=>true)
configure do
  require 'active_record_setup'
  require 'data_mapper_setup'
  require 'sequel_setup'
  require 'se_setup'
end

error StandardError do
  e = request.env['sinatra.error']
  puts e.message
  e.backtrace.each{|x| puts x}
end

class CleanUpARGarbage
  def initialize(app, opts={})
    @app = app
  end
  def call(env)
    res = @app.call(env)
    ActiveRecord::Base.clear_active_connections!
    res
  end
end
use CleanUpARGarbage

scaffold('/active_record', ArOfficer)
scaffold('/active_record', ArMeeting)
scaffold_all_models('/active_record', :only=>[ArEmployee, ArGroup, ArPosition])
scaffold('/data_mapper', DmOfficer)
scaffold('/data_mapper', DmMeeting)
scaffold_all_models('/data_mapper', :only=>[DmEmployee, DmGroup, DmPosition])
scaffold('/sequel', SqOfficer)
scaffold('/sequel', SqMeeting)
scaffold_all_models('/sequel', :only=>[SqEmployee, SqGroup, SqPosition])
