require 'rubygems'
require 'sinatra'
SE_TEST_FRAMEWORK='se_demo'
require 'sequel_setup'
require 'se_setup'
ScaffoldingExtensions.javascript_library = 'JQuery'
set :port=>7980
enable :sessions, :run
disable :clean_trace, :reload

helpers do
  def scaffold_set_flash(notice)
    session[:flash] = notice
  end
  def scaffold_get_flash
    session[:flash]
  end
end

before do
  @flash = session.delete(:flash)
end

get '/' do
  erb :index
end

Sinatra::Application.send(:scaffold_all_models, :only=>[SqEmployee, SqGroup, SqMeeting, SqOfficer, SqPosition])
