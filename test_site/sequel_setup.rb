require 'sequel'
SequelDB = Sequel.sqlite("db/#{SE_TEST_FRAMEWORK}.sequel.sqlite3")
Sequel::Model.typecast_on_assignment = false
Sequel::Model.raise_on_save_failure = false
%w'sq_employee sq_group sq_position sq_officer sq_meeting'.each{|x| require "model/#{x}"}
require 'logger'
#SequelDB.logger = Logger.new(STDOUT)
