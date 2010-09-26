require "rubygems"
require "bundler"
Bundler.setup

Bundler.require

require File.join(File.dirname(__FILE__), "lib", "mass_assignment")

# Set Sinatra's variables
set :app_file, __FILE__
set :root, File.dirname(__FILE__)
set :public, "public"
set :views, "views"

class Notification
  include DataMapper::Resource
  
  property :id, Serial
  property :twitter_user_id, Integer
  # Timestamps
  property :created_at, DateTime
  property :updated_at, DateTime
  
  belongs_to :user, :foreign_key => :twitter_user_id
  
  def self.this_month
    count(:created_at => Date.today - 30..Date.today + 1)
  end
end

class User
  include DataMapper::Resource
  include DataMapper::Validate
  include MassAssignment
  
  mass_assignment :only => [
    :prowl_api_key,
    :enable_mentions,
    :mention_priority,
    :enable_dms,
    :dm_since_id, 
    :dm_priority,
    :enable_list,
    :notification_list,
    :list_priority
  ]
  
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
  
  # Create a new user from session data retrieved from
  # twitter-login/OAuth authorization.
  def self.create_from_twitter(twitter_user, access_key, access_token)
    User.create!( # Fill in the params manually; we only need a few settings
      :twitter_user_id => twitter_user.id,
      :twitter_username => twitter_user.screen_name,
      :access_key => access_key,
      :access_secret => access_token,
      # Because we ignore callbacks
      :created_at => Time.now,
      :updated_at => Time.now
    )
  end
  
  # Check Twitter for new DMs for this user using the REST API
  def check_dms
    # Send any DM notifications -- handle exceptions from the JSON
    # parser in case Twitter sends us back malformed JSON or (more
    # likely) HTML when it's over capacity
    begin
      direct_messages = Twitter::Base.new(oauth).direct_messages(:count => 11, :since_id => dm_since_id)
      
      if direct_messages.size > 0
        # The notification event text depends on the number of new tweets
        if direct_messages.size == 1
          event = "From @#{direct_messages.first['sender']['screen_name']}"
        elsif direct_messages.size == 11
          event = "Over 10 DMs! Latest from @#{direct_messages.first['sender']['screen_name']}"
        else
          event = "#{direct_messages.size} DMs; latest from @#{direct_messages.first['sender']['screen_name']}"
        end
        
        # Update this users's since_id
        update(:dm_since_id => direct_messages.first['id'])
        
        # A since_id of 1 means the user is brand new -- we don't send notifications on the first check
        if dm_since_id != 1
          FastProwl.add(
            :application => AppConfig['app']['name'] + ' DM',
            :providerkey => AppConfig['app']['prowl_provider_key'],
            :apikey => prowl_api_key,
            :priority => dm_priority,
            :event => event,
            :description => direct_messages.first['text']
          )
          Notification.create(:twitter_user_id => twitter_user_id)
        end
      end
    rescue JSON::ParserError => e # Bad data (probably not even JSON) returned for this response
      $log << "\n" + Time.now.to_s + '   @' + twitter_username
      $log << "\n" + 'Twitter was over capacity for @' + twitter_username + "? Couldn't make a usable array from JSON data."
      $log << "\n" + '@' + twitter_username + '   ' + e.to_s
    rescue Timeout::Error => e
      $log << "\n" + Time.now.to_s + '   @' + twitter_username
      $log << "\n" + 'Twitter timed out for @' + twitter_username + "."
      $log << "\n" + '@' + twitter_username + '   ' + e.to_s
    rescue Exception => e # Bad data or some other weird response
      $log << "\n" + Time.now.to_s + '   @' + twitter_username
      $log << "\n" + 'Error getting data for @' + twitter_username + '. Twitter probably returned bad data.'
      $log << "\n" + '@' + twitter_username + '   ' + e.to_s
    end
  end
  
  # Check Twitter for new tweets for any lists Prey Fetcher
  # checks for this user using the REST API.
  def check_lists
    # Send any list notifications -- handle exceptions from the JSON
    # parser in case Twitter sends us back malformed JSON or (more
    # likely) HTML when it's over capacity
    begin
      list_tweets = Twitter::Base.new(oauth).list_timeline(twitter_username, notification_list, :count => 2, :since_id => list_since_id)
      
      if list_tweets.size > 0
        # The notification event text depends on the number of new tweets
        if list_tweets.size == 1
          event = "New tweet by @#{list_tweets.first['user']['screen_name']}"
        else
          event = "New tweets; latest by @#{list_tweets.first['user']['screen_name']}"
        end
        
        # Update this users's since_id
        update(:list_since_id => list_tweets.first['id'])
        
        # Queue up this notification
        FastProwl.add(
          :application => AppConfig['app']['name'] + ' List',
          :providerkey => AppConfig['app']['prowl_provider_key'],
          :apikey => prowl_api_key,
          :priority => list_priority,
          :event => event,
          :description => list_tweets.first['text']
        )
        Notification.create(:twitter_user_id => twitter_user_id)
      end
    rescue JSON::ParserError => e # Bad data (probably not even JSON)
      $log << "\n" + Time.now.to_s + '   @' + twitter_username
      $log << "\n" + 'Twitter was over capacity for @' + twitter_username + "? Couldn't make a usable array from JSON data."
      $log << "\n" + '@' + twitter_username + '   ' + e.to_s
    rescue Timeout::Error => e
      $log << "\n" + Time.now.to_s + '   @' + twitter_username
      $log << "\n" + 'Twitter timed out for @' + twitter_username + "."
      $log << "\n" + '@' + twitter_username + '   ' + e.to_s
    rescue Exception => e # Bad data or some other weird response
      $log << "\n" + Time.now.to_s + '   @' + twitter_username
      $log << "\n" + 'Error getting data for @' + twitter_username + '. Twitter probably returned bad data.'
      $log << "\n" + '@' + twitter_username + '   ' + e.to_s
    end
  end
  
  # Return lists this user owns, includes private lists.
  def lists(force_reload=false)
    return load_lists if force_reload
    
    lists_serialized || load_lists
  end
  
  # Load this users' lists from the REST API, and update their
  # locally stored/serialized lists property.
  def load_lists
    lists = Twitter::Base.new(oauth).lists(twitter_username).lists
    
    update!(:lists_serialized => lists)
    
    list_ids = []
    lists.each do |list|
      list_ids << list.id
    end
    
    # Remove the list this user was
    # following if it no longer exists
    update!(:notification_list => nil) unless lists.size > 0 and list_ids.include?(notification_list)
    
    lists
  end
  
  # Return this user's OAuth instance.
  def oauth
    if @oauth.nil?
      @oauth = Twitter::OAuth.new(AppConfig['twitter']['oauth']['consumer_key'], AppConfig['twitter']['oauth']['consumer_secret'])
      @oauth.authorize_from_access(access_key, access_secret)
    end
    
    @oauth
  end
  
  # Test a user's Prowl API key via the Prowl API.
  def prowl_api_key_is_valid?
    return [false, "You must supply a Prowl API key."] if self.prowl_api_key.nil? || self.prowl_api_key.blank?
    
    if FastProwl.verify(self.prowl_api_key)
      true
    else
      [false, "The Prowl API key you supplied was invalid."]
    end
  end
  
  # Test this user's OAuth credentials and update/verify their username.
  def verify_credentials
    begin
      creds = Twitter::Base.new(oauth).verify_credentials
      
      # Update user's screen name if they've changed it (prevents
      # users who changed their screen name from getting notifications
      # through the Streaming API)
      if twitter_username && twitter_username != creds['screen_name']
        $log << "\n" + "Updating screen name for id \##{id}. Changing name from @#{twitter_username} to @#{creds['screen_name']}"
        update(:twitter_username => creds['screen_name'])
      end
    rescue Twitter::Unauthorized => e # Delete this user; they've revoked access
      $log << "\n" + Time.now.to_s + '   @' + twitter_username
      $log << "\n" + 'Access revoked for @' + twitter_username + ". Deleting Twitter user id " + twitter_user_id.to_s
      $log << "\n" + '@' + twitter_username + '   ' + e.to_s
      
      destroy!
    rescue JSON::ParserError # Bad data (probably not even JSON) returned for this response
      $log << "\n" + Time.now.to_s + '   @' + self.twitter_username
      $log << "\n" + 'Twitter was over capacity for @' + self.twitter_username + "? Couldn't make a usable array from JSON data."
    rescue Timeout::Error
      $log << "\n" + Time.now.to_s + '   @' + self.twitter_username
      $log << "\n" + 'Twitter timed out for @' + self.twitter_username + "."
    rescue Exception # Bad data or some other weird response
      $log << "\n" + Time.now.to_s + '   @' + self.twitter_username
      $log << "\n" + 'Error getting data for @' + self.twitter_username + '. Twitter probably returned bad data.'
    end
  end
end

configure do
  # Load app config from YAML and set it in a constant
  require "yaml"
  
  config = YAML.load_file(File.join(File.dirname(__FILE__), "config.yml"))
  # Local config file for development, testing, overrides
  unless Sinatra::Application.environment == :production
    config.deep_merge!(YAML.load_file(File.join(File.dirname(__FILE__), "config_local.yml"))) if File.exist?(File.join(File.dirname(__FILE__), "config_local.yml"))
  end
  
  # Assemble some extra config values from those already set
  config['app']['url'] = "http://#{config['app']['domain']}"
  config['app']['user_agent'] = "#{config['app']['name']} #{config['app']['version']} (#{config['app']['url']})"
  
  # Put it in a constant so it's not tampered with
  AppConfig = config
  
  db_env = Sinatra::Application.environment.to_s
  
  # Database stuff
  unless AppConfig['database'][db_env]['adapter'] == 'sqlite3'
    DataMapper.setup(:default, "#{AppConfig['database'][db_env]['adapter']}://#{AppConfig['database'][db_env]['username']}:#{AppConfig['database'][db_env]['password']}@#{AppConfig['database'][db_env]['host']}/#{AppConfig['database'][db_env]['database']}")
  else
    DataMapper.setup(:default, "sqlite3:#{AppConfig['database'][db_env]['database']}")
  end
  
  #DataMapper.auto_migrate!
end

helpers do
  # Return a link to an asset file on another domain.
  def asset(file)
    "http://#{AppConfig['app']['asset_domain']}/#{file}"
  end
  
  # Return a number as a string with commas.
  def number_format(number)
    (s=number.to_s;x=s.length;s).rjust(x+(3-(x%3))).scan(/.{3}/).join(',').strip.sub(/^,/, '')
  end
end

# Setup logging...
$log = File.new(File.join(File.dirname(__FILE__), "#{Sinatra::Application.environment}.log"), "a")
# ... but don't log certain things when developing
if Sinatra::Application.environment == :production
  STDOUT.reopen($log)
  STDERR.reopen($log)
end

# We'll need sessions.
enable :sessions

# And flash[]
use Rack::Flash, :sweep => true

# Load the Twitter middleware.
use Twitter::Login,
  :consumer_key => AppConfig['twitter']['oauth']['consumer_key'],
  :secret => AppConfig['twitter']['oauth']['consumer_secret']
helpers Twitter::Login::Helpers

# Index action -- show the homepage.
get "/" do
  # Index page is the entry point after login/signup
  if twitter_user
    unless session[:logged_in]
      flash.now[:notice] = "Logged into Prey Fetcher as @#{twitter_user.screen_name}."
      session[:logged_in] = true
    end
    
    if User.count(:twitter_user_id => twitter_user.id) == 0
      @user = User.create_from_twitter(twitter_user, session[:access_token][0], session[:access_token][1])
      flash[:notice] = "Created Prey Fetcher account for @#{twitter_user.screen_name}.<br><a href=\"#user_prowl_api_key\">Enter your Prowl API key</a> to enable notifications."
      redirect '/settings'
    end
  end
  
  @title = "Open Source Twitter Push Notifications"
  erb :index
end

# Show the FAQ.
get "/faq" do
  @title = "Questions About Prey Fetcher"
  erb :faq
end

# Show the Privacy jazz.
get "/privacy" do
  @title = "Promise To Not Be Evil"
  erb :privacy
end

# Show the OSS page.
get "/open-source" do
  @title = "Open Source"
  erb :open_source
end

# Show account info.
get "/account" do
  @title = "@#{twitter_user.screen_name}'s Account"
  @user = User.first(:twitter_user_id => twitter_user.id)
  erb :account
end

# Show account info.
delete "/account" do
  @user = User.first(:twitter_user_id => twitter_user.id)
  @user.destroy!
  
  flash[:notice] = "Your Prey Fetcher account has been deleted. Sorry to see you go!"
  twitter_logout
  session[:logged_in] = false
  redirect '/'
end

# Edit account settings.
get "/settings" do
  @title = "Change Your Notification Settings"
  @user = User.first(:twitter_user_id => twitter_user.id)
  erb :settings
end

# Receive new account settings.
put "/settings" do
  @user = User.first(:twitter_user_id => twitter_user.id)
  if @user.update(params[:user])
    flash[:notice] = "Your settings have been updated."
    redirect '/settings'
  else
    flash.now[:alert] = "Sorry, but your account couldn't be updated.<br><ul>"
    @user.errors.each do |e|
      flash.now[:alert] << "<li>#{e}</li>"
    end
    flash.now[:alert] << "</ul>"
    @title = "Change Your Notification Settings"
    erb :settings
  end
end

# Put request that updates a user's lists from Twitter.
put "/lists" do
  @user = User.first(:twitter_user_id => twitter_user.id)
  unless @user.nil?
    @user.lists(true)
    flash[:notice] = "Your Twitter lists have been updated."
    redirect '/settings'
  else
    flash[:error] = "No user matching your Twitter account was found."
    redirect '/'
  end
end

# Logout and remove any session data.
get "/logout" do
  flash[:notice] = "Logged @#{twitter_user.screen_name} out of Prey Fetcher."
  twitter_logout
  session[:logged_in] = false
  redirect '/'
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
unless Sinatra::Application.environment == :production
  get '/stylesheets/:file.css' do |file|
    content_type 'text/css', :charset => 'utf-8'
    sass file.to_sym
  end
end
