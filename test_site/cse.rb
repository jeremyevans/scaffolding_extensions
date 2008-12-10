#!/usr/local/bin/ruby
require 'rubygems'
require 'camping'
require 'mongrel'
require 'mongrel/camping'

Camping.goes :Cse
SE_TEST_FRAMEWORK='camping'
require 'active_record_setup'
require 'sequel_setup'
require 'se_setup'

module Cse
  module Controllers
    class ActiveRecord < scaffold_R("/active_record")
      scaffold ArOfficer
      scaffold ArMeeting
      scaffold_all_models :only=>[ArEmployee, ArGroup, ArPosition]
    end
    class Sequel < scaffold_R("/sequel")
      scaffold SqOfficer
      scaffold SqMeeting
      scaffold_all_models :only=>[SqEmployee, SqGroup, SqPosition]
    end
  end
  
  def service(*args)
    r = super(*args)
    ActiveRecord::Base.clear_active_connections!
    r
  end
end

Mongrel::Camping::start("0.0.0.0",7977,"/",Cse).run.join rescue nil
