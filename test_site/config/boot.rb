require 'rubygems'
if RUBY_VERSION > '1.9'
  gem 'rails', '4.0.2'
else
  gem 'rails', '3.2.12'
end

# Set up gems listed in the Gemfile.
ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../Gemfile', __FILE__)

#require 'bundler/setup' if File.exists?(ENV['BUNDLE_GEMFILE'])
