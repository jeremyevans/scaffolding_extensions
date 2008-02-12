require 'rubygems'
require 'ramaze'
require 'active_record'

ActiveRecord::Base.establish_connection(:adapter=>'sqlite3', :database=>'db/db.sqlite3')

$:.unshift('vendor/plugins/scaffolding_extensions/lib')
require 'scaffolding_extensions'

acquire __DIR__/:model/'*'
acquire __DIR__/:controller/'*'

Ramaze::Inform.loggers = []
Ramaze.start :adapter => :mongrel, :port => 7000
