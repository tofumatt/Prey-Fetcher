require "rubygems"
require "sinatra"
require "haml"
#require "sass"
#require "json"

# Set Sinatra's variables
set :app_file, __FILE__
set :root, File.dirname(__FILE__)
set :public, 'public'
set :views, 'views'

get '/' do
  "Push your tweets to nowhere."
end
