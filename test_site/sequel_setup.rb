require 'sequel'
SequelDB = Sequel.sqlite("db/#{SE_TEST_FRAMEWORK}.sequel.sqlite3")
%w'sq_employee sq_group sq_position sq_officer sq_meeting'.each{|x| require "model/#{x}"}
require 'logger'
#SequelDB.logger = Logger.new(STDOUT)
require 'sequel/extensions/inflector'
