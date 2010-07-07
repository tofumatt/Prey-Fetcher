unless ENV['RACK_ENV'] == "production"
  # Development mode
  require "rubygems"
  require "bundler"
  Bundler.setup
else
  # Production mode (locked)
  require ".bundle/environment"
end

Bundler.require

# Set Sinatra's variables
set :app_file, File.join(File.dirname(__FILE__), __FILE__)
set :environment, ENV['RACK_ENV'].to_sym
set :root, File.dirname(__FILE__)
set :public, "public"
set :views, "views"
disable :run

run Sinatra::Application