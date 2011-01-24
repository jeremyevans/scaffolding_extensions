require "dm-core"
require "dm-validations"
require "dm-transactions"
require "data_objects"
require "do_sqlite3"
DataMapper.setup(:default, "sqlite3:db/#{SE_TEST_FRAMEWORK}.datamapper.sqlite3")
%w'dm_employee dm_group dm_position dm_officer dm_meeting'.each{|x| require "model/#{x}"}
require 'model/dm_resources'
