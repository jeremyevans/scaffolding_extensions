ENV["RAILS_ENV"] ||= ENV["RACK_ENV"]
require "config/environment"
require 'action_controller/rack_lint_patch'
use Rails::Rack::Static
run ActionController::Dispatcher.new

