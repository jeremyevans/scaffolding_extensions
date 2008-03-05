require 'rubygems'
require 'ramaze'
SE_TEST_FRAMEWORK='ramaze'
require 'active_record_setup'
require 'data_mapper_setup'
require 'se_setup'
require 'controller/main'

#Ramaze::Inform.loggers = []
Ramaze.start :adapter => :mongrel, :port => 7978
