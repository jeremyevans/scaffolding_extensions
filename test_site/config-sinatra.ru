#!/usr/local/bin/ruby
$: << '.'
require 'rubygems'
::SE_TEST_FRAMEWORK='sinatra'
require 'sinatra/base'
require 'ar_garbage'

class Sinatra::Base
  set(:environment=>:development, :app_file=>'sinatra_se.rb', :raise_errors=>true, :views=>'blah')
  disable :run
  configure do
    require 'datamapper_setup'
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
  set(:views=>'views')
  scaffold SqOfficer
  scaffold SqMeeting
  scaffold_all_models :only=>[SqEmployee, SqGroup, SqPosition]
end

class ActiveRecordController < Sinatra::Base
  set(:views=>'views2')
  scaffold ArOfficer
  scaffold ArMeeting
  scaffold_all_models :only=>[ArEmployee, ArGroup, ArPosition]
end

class DatamapperController < Sinatra::Base
  add_scaffolding_methods [DmOfficer, DmMeeting, DmEmployee, DmGroup, DmPosition]
  scaffold DmOfficer
  scaffold DmMeeting
  scaffold_all_models :only=>[DmEmployee, DmGroup, DmPosition]
end

app = Rack::Builder.app do
  map "/sequel" do
    run SequelController
  end
  map "/active_record" do
    use CleanUpARGarbage
    run ActiveRecordController
  end
  map "/datamapper" do
    run DatamapperController
  end
  run Rack::File.new("public")
end
run app
