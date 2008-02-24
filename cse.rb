#!/usr/local/bin/ruby
require 'rubygems'
require 'camping'
require 'mongrel'
require 'mongrel/camping'

Camping.goes :Cse

require 'active_record'
ActiveRecord::Base.establish_connection(:adapter=>'sqlite3', :database=>'db/camping.active_record.sqlite3')
#ActiveRecord::Base.connection.instance_variable_set('@logger', Logger.new(STDOUT))
require 'model/ar_employee'
require 'model/ar_group'
require 'model/ar_position'
require 'model/ar_officer'

require 'data_mapper'
DataMapper::Database.setup(:adapter=>:sqlite3, :database=>'db/camping.data_mapper.sqlite3')
DataMapper::Adapters::Sqlite3Adapter::TRUE_ALIASES << 't'.freeze
DataMapper::Adapters::Sqlite3Adapter::FALSE_ALIASES << 'f'.freeze
require 'model/dm_employee'
require 'model/dm_group'
require 'model/dm_position'
require 'model/dm_officer'

$:.unshift('vendor/plugins/scaffolding_extensions/lib')
require 'scaffolding_extensions'

ScaffoldingExtensions::MetaModel::SCAFFOLD_OPTIONS[:search_limit] = 1
ScaffoldingExtensions::MetaModel::SCAFFOLD_OPTIONS[:browse_limit] = 1

module Cse::Controllers
  class ActiveRecord < scaffold_R("/active_record")
    scaffold ArOfficer
    scaffold_all_models :only=>[ArEmployee, ArGroup, ArPosition]
  end
  class DataMapper < scaffold_R("/data_mapper")
    scaffold DmOfficer
    scaffold_all_models :only=>[DmEmployee, DmGroup, DmPosition]
  end
end

Mongrel::Camping::start("0.0.0.0",7977,"/",Cse).run.join rescue nil
