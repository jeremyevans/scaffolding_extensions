#!/usr/local/bin/ruby
require 'rubygems'
require 'camping'
require 'mongrel'
require 'mongrel/camping'

Camping.goes :Cse
SE_TEST_FRAMEWORK='camping'
require 'active_record_setup'
require 'data_mapper_setup'
require 'se_setup'

module Cse::Controllers
  class ActiveRecord < scaffold_R("/active_record")
    scaffold ArOfficer
    scaffold ArMeeting
    scaffold_all_models :only=>[ArEmployee, ArGroup, ArPosition]
  end
  class DataMapper < scaffold_R("/data_mapper")
    scaffold DmOfficer
    scaffold DmMeeting
    scaffold_all_models :only=>[DmEmployee, DmGroup, DmPosition]
  end
end

Mongrel::Camping::start("0.0.0.0",7977,"/",Cse).run.join rescue nil
