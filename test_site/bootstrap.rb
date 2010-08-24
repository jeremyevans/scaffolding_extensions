#!/usr/bin/env ruby
require 'rubygems'
FRAMEWORKS=%w'ramaze camping sinatra merb rack'
ORMS=%w'active_record sequel datamapper'
SE_TEST_FRAMEWORK='rails'
# Make log and tmp directories
system 'mkdir -p log tmp tmp/{sessions,sockets,cache,pids}'
# Make sure log files exist to shut up Rails
system 'touch log/{development,production,test}.log'
# Create the Rails databases
system 'rake db:create'
system 'rake db:migrate'
require 'sequel_setup'
Sequel::Migrator.apply(SequelDB, 'db/sequel_migrate')
require 'datamapper_setup'
DataMapper.auto_migrate!
# Copy the Rails databases to the other frameworks
FRAMEWORKS.each{|f| ORMS.each{|o| system "cp db/#{SE_TEST_FRAMEWORK}.#{o}.sqlite3 db/#{f}.#{o}.sqlite3"}}
