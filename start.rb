require 'rubygems'
require 'ramaze'
require 'active_record'
$:.unshift('data_mapper/lib')
require 'data_mapper'

ActiveRecord::Base.establish_connection(:adapter=>'sqlite3', :database=>'db/ramaze.active_record.sqlite3')
DataMapper::Database.setup(:adapter=>:sqlite3, :database=>'db/ramaze.data_mapper.sqlite3')

$:.unshift('vendor/plugins/scaffolding_extensions/lib')
require 'scaffolding_extensions'

ScaffoldingExtensions::MetaModel::SCAFFOLD_OPTIONS[:search_limit] = 1
ScaffoldingExtensions::MetaModel::SCAFFOLD_OPTIONS[:browse_limit] = 1

acquire __DIR__/:model/'*'
acquire __DIR__/:controller/'*'

#Ramaze::Inform.loggers = []
Ramaze.start :adapter => :mongrel, :port => 7978
