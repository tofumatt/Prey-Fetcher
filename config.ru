require "rubygems"
require "bundler"
Bundler.setup

Bundler.require

require File.join(File.dirname(__FILE__), "web.rb")

# Set Sinatra's variables
set :app_file, File.join(File.dirname(__FILE__), "web.rb")
set :environment, ENV['RACK_ENV'].to_sym
set :root, File.dirname(__FILE__)
set :public, "public"
set :views, "views"
disable :run

run Sinatra::Application
