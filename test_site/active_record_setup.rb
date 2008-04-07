require 'active_record'
ActiveRecord::Base.establish_connection(:adapter=>'sqlite3', :database=>"db/#{SE_TEST_FRAMEWORK}.active_record.sqlite3")
require 'model/ar_employee'
require 'model/ar_group'
require 'model/ar_position'
require 'model/ar_officer'
require 'model/ar_meeting'
#ActiveRecord::Base.connection.instance_variable_set('@logger', Logger.new(STDOUT))
