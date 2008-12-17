#!/usr/local/bin/ruby
require 'rubygems'
SE_TEST_FRAMEWORK='sinatra'
require 'sinatra'
set(:port=>7976, :host=>'0.0.0.0', :env=>:production, :app_file=>'sinatra_se_sq', :raise_errors=>true, :logging=>true)
configure do
  require 'sequel_setup'
  require 'se_setup'
end

error StandardError do
  e = request.env['sinatra.error']
  puts e.message
  e.backtrace.each{|x| puts x}
end

scaffold('/sequel', SqOfficer)
scaffold('/sequel', SqMeeting)
scaffold_all_models('/sequel', :only=>[SqEmployee, SqGroup, SqPosition])
