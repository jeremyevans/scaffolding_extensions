#!/usr/local/bin/ruby
require 'rubygems'
require 'camping'
require 'rack'

Camping.goes :Cse
SE_TEST_FRAMEWORK='camping'
require 'datamapper_setup'
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
    class Datamapper < scaffold_R("/datamapper")
      add_scaffolding_methods [DmOfficer, DmMeeting, DmEmployee, DmGroup, DmPosition]
      scaffold DmOfficer
      scaffold DmMeeting
      scaffold_all_models :only=>[DmEmployee, DmGroup, DmPosition]
    end
  end

  def service(*args)
    r = super(*args)
    ActiveRecord::Base.clear_active_connections!
    r
  end

  puts "** Starting Mongrel on 0.0.0.0:7977"
  Rack::Handler::Mongrel.run(self, :Port => 7977, :Host => '0.0.0.0')
end

