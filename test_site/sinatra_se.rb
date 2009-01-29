#!/usr/local/bin/ruby
require 'rubygems'
SE_TEST_FRAMEWORK='sinatra'
require 'sinatra/base'

class Sinatra::Base
  set(:environment=>:production, :app_file=>'sinatra_se_sq', :raise_errors=>true, :logging=>true)
  disable :run
  configure do
    require 'active_record_setup'
    require 'sequel_setup'
    require 'se_setup'
  end
  error StandardError do
    e = request.env['sinatra.error']
    puts e.message
    e.backtrace.each{|x| puts x}
  end
end

class SequelController < Sinatra::Base
  scaffold SqOfficer
  scaffold SqMeeting
  scaffold_all_models :only=>[SqEmployee, SqGroup, SqPosition]
end

class ActiveRecordController < Sinatra::Base
  scaffold ArOfficer
  scaffold ArMeeting
  scaffold_all_models :only=>[ArEmployee, ArGroup, ArPosition]
end

class CleanUpARGarbage
  def initialize(app, opts={})
    @app = app
  end
  def call(env)
    res = @app.call(env)
    ActiveRecord::Base.clear_active_connections!
    res
  end
end

app = Rack::Builder.app do
  map "/sequel" do
    run SequelController
  end
  map "/active_record" do
    use CleanUpARGarbage
    run ActiveRecordController
  end
end 

puts "== Sinatra/#{Sinatra::VERSION} has taken the stage on 7976 with backup from Mongrel"
Rack::Handler.get('mongrel').run(app, :Host=>'0.0.0.0', :Port=>7976) do |server|
  trap(:INT) do 
    server.stop
    puts "\n== Sinatra has ended his set (crowd applauds)"
  end
end
