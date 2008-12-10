ENV['FORK'] = '0'
require 'rubygems'
$:.unshift('/data/code/merb/merb-core/lib')
require 'merb-core'
SE_TEST_FRAMEWORK='merb'
require 'active_record_setup'
require 'sequel_setup'
require 'se_setup'

use_template_engine :erb

Merb::Config.use { |c|
  c[:session_store]       = 'cookie'
  c[:session_secret_key]  = 'cookie'*10
  c[:exception_details]   = true
	c[:log_level]           = :debug
  c[:log_stream]          = $stdout
	c[:reload_classes]   = false
	c[:reload_templates] = false
	c[:use_mutex] = false
	c[:fork_for_class_load] = false
  c[:framework] = {:application=>["", nil], :view=>[nil, nil], :public=>["p", nil], :model=>["m", nil], :helper=>["h", nil], :controller=>["c", nil], :mailer=>[nil, nil], :part=>[nil, nil], :config=>["", nil], :router=>["", nil], :lib=>["l", nil], :merb_session=>[nil, nil], :log=>[nil, nil], :stylesheet=>[nil, nil], :javascript=>[nil, nil], :image=>[nil, nil]}
}

Merb::Router.prepare do
  default_routes
end

class Ar < Merb::Controller
  after :clean_up_ar_garbage
  scaffold ArOfficer
  scaffold ArMeeting
  scaffold_all_models :only=>[ArEmployee, ArGroup, ArPosition]
  private
  def clean_up_ar_garbage
    ActiveRecord::Base.clear_active_connections!
  end
end
class Asq < Merb::Controller
  scaffold SqOfficer
  scaffold SqMeeting
  scaffold_all_models :only=>[SqEmployee, SqGroup, SqPosition]
end

Merb.disable(:initfile)
Merb.start(%w'-a mongrel')
