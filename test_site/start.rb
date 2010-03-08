#!/usr/bin/env ruby
require 'rubygems'
require 'ramaze'
SE_TEST_FRAMEWORK='ramaze'
class String
  undef_method :start_with?
end
require 'active_record_setup'
require 'sequel_setup'
require 'datamapper_setup'
require 'se_setup'
require 'controller/main'
require 'ar_garbage'

#Ramaze::Inform.loggers = []
Ramaze.start(:adapter => :mongrel, :port => 7978, :mode => :live){|m| m.use CleanUpARGarbage; m.run Ramaze::AppMap}
