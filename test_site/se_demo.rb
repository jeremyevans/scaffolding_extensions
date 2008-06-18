require 'rubygems'
require 'ramaze'
SE_TEST_FRAMEWORK='se_demo'
require 'sequel_setup'
require 'se_setup'
ScaffoldingExtensions.javascript_library = 'JQuery'

class MainController < Ramaze::Controller
  layout :se_layout
  scaffold_all_models :only=>[SqEmployee, SqGroup, SqMeeting, SqOfficer, SqPosition]
end

Ramaze.start :adapter=>:mongrel, :port=>7980, :sourcereload=>false, :force=>true, :test_connections=>false
