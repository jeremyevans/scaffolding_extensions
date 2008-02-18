$:.unshift("#{RAILS_ROOT}/data_mapper/lib")
require 'data_mapper'
DataMapper::Database.setup(:adapter=>:sqlite3, :database=>"#{RAILS_ROOT}/db/rails.data_mapper.sqlite3")
%w'dm_employee dm_employee_group dm_group dm_position scaffolding_extensions/model/data_mapper'.each{|x| require x}
