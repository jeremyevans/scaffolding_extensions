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

Ramaze.options.mode = :live
use CleanUpARGarbage
Ramaze.start(:root => File.dirname(File.expand_path(__FILE__)), :started => true)
run Ramaze
