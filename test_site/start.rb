#!/usr/bin/env ruby
require 'rubygems'
require 'ramaze'
SE_TEST_FRAMEWORK='ramaze'
class String
  undef_method :start_with?
end
require 'active_record_setup'
require 'data_mapper_setup'
require 'sequel_setup'
require 'se_setup'
require 'controller/main'

#Ramaze::Inform.loggers = []
Ramaze::Global.adapter = :mongrel
Ramaze::Global.port = 7978
#Ramaze.start
