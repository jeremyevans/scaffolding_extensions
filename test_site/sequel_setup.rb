$:.unshift('/data/code/sequel/lib')
require 'sequel'
Sequel.single_threaded = true
SequelDB = Sequel.sqlite("db/#{SE_TEST_FRAMEWORK}.sequel.sqlite3", :single_threaded=>true, :foreign_keys=>false)
Sequel::Model.plugin :prepared_statements
Sequel::Model.plugin :prepared_statements_associations
%w'sq_employee sq_group sq_position sq_officer sq_meeting'.each{|x| require "model/#{x}"}
require 'logger'
SequelDB.logger = Logger.new(STDOUT)
require 'sequel/extensions/inflector'
require 'sequel/extensions/migration'
