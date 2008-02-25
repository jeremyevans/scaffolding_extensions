#!/usr/local/bin/ruby
require 'rubygems'

require 'active_record'
ActiveRecord::Base.establish_connection(:adapter=>'sqlite3', :database=>'db/sinatra.active_record.sqlite3')
#ActiveRecord::Base.connection.instance_variable_set('@logger', Logger.new(STDOUT))
require 'model/ar_employee'
require 'model/ar_group'
require 'model/ar_position'
require 'model/ar_officer'

require 'data_mapper'
DataMapper::Database.setup(:adapter=>:sqlite3, :database=>'db/sinatra.data_mapper.sqlite3')
DataMapper::Adapters::Sqlite3Adapter::TRUE_ALIASES << 't'.freeze
DataMapper::Adapters::Sqlite3Adapter::FALSE_ALIASES << 'f'.freeze
require 'model/dm_employee'
require 'model/dm_group'
require 'model/dm_position'
require 'model/dm_officer'

require 'sinatra'

module Sinatra::Options
  def log_file
    "log/sinatra-#{environment}.log"
  end
end
module Sinatra::Loader
  def reload!
    nil
  end
end

unless defined?(ScaffoldingExtensions)
  $:.unshift('vendor/scaffolding_extensions/lib')
  require 'scaffolding_extensions'
end

ScaffoldingExtensions::MetaModel::SCAFFOLD_OPTIONS[:search_limit] = 1
ScaffoldingExtensions::MetaModel::SCAFFOLD_OPTIONS[:browse_limit] = 1

scaffold('/active_record', ArOfficer)
scaffold_all_models('/active_record', :only=>[ArEmployee, ArGroup, ArPosition])
scaffold('/data_mapper', DmOfficer)
scaffold_all_models('/data_mapper', :only=>[DmEmployee, DmGroup, DmPosition])
