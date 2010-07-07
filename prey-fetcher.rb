# Development mode
require "rubygems"
require "bundler"
Bundler.setup

# Production mode (locked)
# require ".bundle/environment"

Bundler.require

# Set Sinatra's variables
set :app_file, __FILE__
set :root, File.dirname(__FILE__)
set :public, "public"
set :views, "views"

configure do
  # Load app config from YAML and set it in a constant
  require "yaml"
  
  config = YAML.load_file("config.yml")
  # Local config file for development, testing, overrides
  unless Sinatra::Application.environment == 'production'
    config.merge!(YAML.load_file("config_local.yml")) if File.exist?(File.join(File.dirname(__FILE__), "config_local.yml"))
  end
  
  # Assemble some extra config values from those already set
  config['app']['url'] = "http://#{config['app']['domain']}"
  config['app']['user_agent'] = "#{config['app']['name']} #{config['app']['version']} (#{config['app']['url']})"
  
  # Put it in a constant so it's not tampered with
  AppConfig = config
end

helpers do
  def asset(file)
    "http://#{AppConfig['app']['asset_domain']}/#{file}"
  end
  
  # Return a number as a string with commas
  def number_format(number)
    (s=number.to_s;x=s.length;s).rjust(x+(3-(x%3))).scan(/.{3}/).join(',').strip.sub(/^,/, '')
  end
end

# We'll need sessions
use Rack::Session::Cookie, :key => '_preyfetcher_session',
  :domain => AppConfig['app']['domain'],
  :path => '/',
  :expire_after => 2592000, # In seconds
  :secret => AppConfig['app']['session_key']

# Load the Twitter middleware
use Twitter::Login, :consumer_key => AppConfig['twitter']['oauth']['consumer_key'], :secret => AppConfig['twitter']['oauth']['consumer_secret']
helpers Twitter::Login::Helpers

class Notification
  include DataMapper::Resource
  
  property :id, Serial
  property :twitter_user_id, Integer
  # Timestamps
  property :created_at, DateTime
  property :updated_at, DateTime
  
  belongs_to :user, :foreign_key => :twitter_user_id
  
  def self.this_month
	  count(:conditions => { :created_at => Date.today - 30..Date.tomorrow })
	end
end

class User
  include DataMapper::Resource
  include DataMapper::Validate
  
  property :id, Serial
  property :twitter_user_id, Integer
  property :twitter_username, String
  property :prowl_api_key, String
  property :access_key, String
  property :access_secret, String
  # Mentions/replies
  property :enable_mentions, Boolean, :default => true
  property :mention_priority, Integer, :default => 0
  # Direct Messages
  property :enable_dms, Boolean, :default => true
  property :dm_since_id, Integer, :default => 1
  property :dm_priority, Integer, :default => 0
  # Lists
  property :enable_list, Boolean, :default => true
  property :notification_list, Integer
  property :list_priority, Integer, :default => 0
  property :list_since_id, Integer, :default => 1
  property :list_owner, String
  property :lists_serialized, Object
  # Timestamps
  property :created_at, DateTime
  property :updated_at, DateTime
  
  has n, :notifications
  
  validates_with_method :prowl_api_key, :method => :prowl_api_key_is_valid?
  
  # Test a user's Prowl API key via the Prowl API
  def prowl_api_key_is_valid?
    return [false, "You must supply a Prowl API key."] if self.prowl_api_key.nil? || self.prowl_api_key.blank?
    
    require "fastprowl"
    #logger.debug Time.now.to_s
    #logger.debug 'Validating a Prowl API Key...'
    
    if FastProwl.verify(self.prowl_api_key)
      true
    else
      [false, "The Prowl API key you supplied was invalid."]
    end
  end
end

# Index action -- show the homepage
get "/" do
  @title = "Open Source Twitter Push Notifications"
  erb :index
end

# Show the FAQ
get "/faq" do
  @title = "Questions About Prey Fetcher"
  erb :faq
end

# Show the Privacy jazz
get "/privacy" do
  @title = "Promise To Not Be Evil"
  erb :privacy
end

# Show the OSS page
get "/open-source" do
  @title = "Open Source"
  erb :open_source
end

# 404
not_found do
  @title = "Page Not Found"
  erb :'404'
end

# Any other error
error do
  @title = "Bad Server, Bad!"
  erb :'500'
end

# Non production mode routes
unless Sinatra::Application.environment == 'production'
  get '/stylesheets/:file.css' do |file|
    content_type 'text/css', :charset => 'utf-8'
    sass file.to_sym
  end
end
