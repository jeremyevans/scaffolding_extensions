$:.unshift("data_mapper/lib")
require 'data_mapper'
DataMapper::Database.setup(:adapter=>:sqlite3, :database=>"db/#{SE_TEST_FRAMEWORK}.data_mapper.sqlite3")
# DATAMAPPER_BUG: Must have models for HABTM join tables
%w'dm_employee_group dm_officer_group dm_group_meeting dm_meeting_position'.each{|x| require "model/#{x}"}
%w'dm_employee dm_group dm_position dm_officer dm_meeting'.each{|x| require "model/#{x}"}
#DataMapper.database.logger.level = 0
#DataMapper.database.logger.instance_variable_set(:@logdev, STDOUT)

