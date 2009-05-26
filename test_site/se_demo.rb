require 'rubygems'
require 'sinatra'
SE_TEST_FRAMEWORK='se_demo'
require 'sequel_setup'
require 'se_setup'
ScaffoldingExtensions.javascript_library = 'JQuery'
set :port=>7980

get '/' do
  erb :index
end

Sinatra::Application.send(:scaffold_all_models, :only=>[SqEmployee, SqGroup, SqMeeting, SqOfficer, SqPosition])
