require "rubygems"
require "bundler"
Bundler.setup

Bundler.require

# Current version number + prefix. Gets used in
# as the User Agent in REST/Streaming requests.
PREYFETCHER_VERSION = "4.1.4"

# Set Sinatra's variables
set :app_file, __FILE__
set :environment, (ENV['RACK_ENV']) ? ENV['RACK_ENV'].to_sym : :development
set :root, File.dirname(__FILE__)
set :public, "public"
set :views, "views"

# Monkey patch String to allow unescaped Twitter strings
class String
  # Return true if this text string looks like a retweet
  def retweet?
    self.index('RT ') == 0
  end
  
  # Return a string with &lt; and &gt; HTML entities converted to < and >
  def unescaped
    self.gsub('&lt;', '<').gsub('&gt;', '>')
  end
end

# House internal methods and junk inside our own namespace
class PreyFetcher
  # Protect code run inside this method (as a block) from common
  # exceptions we run into doing Twitter REST API requests.
  def self.protect_from_twitter
    # Do something with Twitter API response -- handle exceptions
    # from the JSON parser in case Twitter sends us back malformed
    # JSON or (more likely) HTML when it's over capacity/down.
    begin
      yield
    rescue JSON::ParserError => e # Bad data (probably not even JSON) returned for this response
      puts Time.now.to_s
      puts "Twitter was over capacity? Couldn't make a usable array from JSON data."
      puts e.to_s
    rescue Timeout::Error => e
      puts Time.now.to_s
      puts "Twitter timed out."
      puts e.to_s
    rescue Exception => e # Bad data or some other weird response
      puts Time.now.to_s
      puts "Error getting data. Twitter probably returned bad data."
      puts e.to_s
    end
  end
end

# Record of when a notification, including the user record it relates
# to, when it was sent, and the item associated with it.
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

# A user on the site with a Prowl API Key, Twitter credentials, and settings.
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
  property :mention_since_id, Integer, :default => 1
  # Retweets
  property :disable_retweets, Boolean, :default => true # I regret naming it like this now... -- Matt
  property :retweet_priority, Integer, :default => 0
  property :retweet_since_id, Integer, :default => 1
  # Direct Messages
  property :enable_dms, Boolean, :default => true
  property :dm_priority, Integer, :default => 0
  property :dm_since_id, Integer, :default => 1
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
    
    # Load the user from the DB and try to set their since_ids
    user = User.first(:twitter_user_id => twitter_user.id)
    
    # If we can't get the data, it's OK. But it's nicer to set
    # this stuff on account creation.
    PreyFetcher.protect_from_twitter do
      direct_messages = Twitter::Base.new(user.oauth).direct_messages(:count => 1)
      user.update!(:dm_since_id => direct_messages.first['id']) if direct_messages.size > 0
      
      mentions = Twitter::Base.new(user.oauth).mentions(:count => 1)
      user.update!(:mention_since_id => mentions.first['id']) if mentions.size > 0
    end
  end
  
  # Return a list of values we allow routes to mass-assign
  # to a User.
  def self.mass_assignable
    [
      :prowl_api_key,
      :enable_mentions,
      :mention_priority,
      :disable_retweets,
      :retweet_priority,
      :enable_dms,
      :dm_priority,
      :enable_list,
      :notification_list,
      :list_priority
    ]
  end
  
  # Check Twitter for new DMs for this user using the REST API
  def check_dms
    PreyFetcher.protect_from_twitter do
      direct_messages = Twitter::Base.new(oauth).direct_messages(
        :count => 1,
        :since_id => dm_since_id
      )
      
      if direct_messages.size > 0
        # A since_id of 1 means the user is brand new -- we don't send notifications on the first check
        if dm_since_id != 1
          send_dm(
            :id => direct_messages.first['id'],
            :from => direct_messages.first['sender']['screen_name'],
            :text => direct_messages.first['text']
          )
        end
      end
    end
  end
  
  # Check Twitter for new tweets for any lists Prey Fetcher
  # checks for this user using the REST API.
  def check_lists
    PreyFetcher.protect_from_twitter do
      list_tweets = Twitter::Base.new(oauth).list_timeline(twitter_username, notification_list,
        :count => 1,
        :since_id => list_since_id
      )
      
      if list_tweets.size > 0
        send_list(
          :id => list_tweets.first['id'],
          :from => list_tweets.first['user']['screen_name'],
          :text => list_tweets.first['text']
        )
      end
    end
  end
  
  # Look for the most recent mention. If we missed more than one
  # for some reason, it just gets ignored.
  def check_mentions
    PreyFetcher.protect_from_twitter do
      mentions = Twitter::Base.new(oauth).mentions(
        :count => 1,
        :include_entities => 1,
        :include_rts => 0,
        :since_id => mention_since_id
      )
      
      if mentions.size > 0
        # Make sure this isn't an old-style RT
        return if mentions.first['text'].retweet?
        
        user.send_mention(
          :id => mentions.first['id'],
          :from => mentions.first['user']['screen_name'],
          :text => mentions.first['text']
        )
      end
    end
  end
  
  # Return the opposite of "disable_retweets"; here for convenience, as Matt
  # stupidly classes retweets as a subset of mentions at first.
  def enable_retweets
    !disable_retweets
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
      @oauth = Twitter::OAuth.new(PREYFETCHER_CONFIG[:twitter_consumer_key], PREYFETCHER_CONFIG[:twitter_consumer_secret])
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
  
  # Send a DM notification to Prowl for this user.
  def send_dm(tweet)
    # Update this users's since_id
    update(:dm_since_id => tweet[:id])
    
    FastProwl.add(
      :application => "#{PREYFETCHER_CONFIG[:app_prowl_appname]} DM",
      :providerkey => PREYFETCHER_CONFIG[:app_prowl_provider_key],
      :apikey => prowl_api_key,
      :priority => dm_priority,
      :event => "From @#{tweet[:from]}",
      :description => tweet[:text].unescaped
    )
    Notification.create(:twitter_user_id => twitter_user_id)
  end
  
  # Send a List notification to Prowl for this user.
  def send_list(tweet)
    # Update this users's since_id
    update(:list_since_id => tweet[:id])
    
    # Queue up this notification
    FastProwl.add(
      :application => "#{PREYFETCHER_CONFIG[:app_prowl_appname]} List",
      :providerkey => PREYFETCHER_CONFIG[:app_prowl_provider_key],
      :apikey => prowl_api_key,
      :priority => list_priority,
      :event => "by @#{tweet[:from]}",
      :description => tweet[:text].unescaped
    )
    Notification.create(:twitter_user_id => twitter_user_id)
  end
  
  # Send a mention notification to Prowl for this user.
  def send_mention(tweet)
    # Update this users's since_id
    update(:mention_since_id => tweet[:id])
    
    FastProwl.add(
      :application => "#{PREYFETCHER_CONFIG[:app_prowl_appname]} mention",
      :providerkey => PREYFETCHER_CONFIG[:app_prowl_provider_key],
      :apikey => prowl_api_key,
      :priority => mention_priority,
      :event => "From @#{tweet[:from]}",
      :description => tweet[:text].unescaped
    )
    Notification.create(:twitter_user_id => twitter_user_id)
  end
  
  # Send a retweet notification to Prowl for this user.
  def send_retweet(tweet)
    # Update this users's since_id
    update(:retweet_since_id => tweet[:id])
    
    FastProwl.add(
      :application => "#{PREYFETCHER_CONFIG[:app_prowl_appname]} retweet",
      :providerkey => PREYFETCHER_CONFIG[:app_prowl_provider_key],
      :apikey => prowl_api_key,
      :priority => retweet_priority,
      :event => "From @#{tweet[:from]}",
      :description => tweet[:text].unescaped
    )
    Notification.create(:twitter_user_id => twitter_user_id)
  end
  
  # Test this user's OAuth credentials and update/verify their username.
  def verify_credentials
    PreyFetcher.protect_from_twitter do
      creds = Twitter::Base.new(oauth).verify_credentials
      
      # Update user's screen name if they've changed it (prevents
      # users who changed their screen name from getting notifications
      # through the Streaming API)
      if twitter_username && twitter_username != creds['screen_name']
        puts "Updating screen name for id \##{id}. Changing name from @#{twitter_username} to @#{creds['screen_name']}"
        update(:twitter_username => creds['screen_name'])
      end
    end
  end
end

configure do
  # Default values to store in our CONFIG hash
  config_defaults = {
    # Regular app config
    :app_asset_domain => '0.0.0.0:4567',
    :app_domain => '0.0.0.0:4567',
    :app_name => 'Prey Fetcher',
    :app_prowl_appname => 'Prey Fetcher',
    :app_prowl_provider_key => nil,
    
    # Assume development; use SQLite3
    :db_adapter => 'sqlite3',
    :db_host => nil,
    :db_database => 'development.sqlite3',
    :db_username => nil,
    :db_password => nil,
    
    # Twitter configs
    :twitter_consumer_key => '',
    :twitter_consumer_secret => '',
    :twitter_access_key => '',
    :twitter_access_secret => '',
    :twitter_site_stream_size => 100
  }
  
  # Grab stuff from config.rb, if it exists
  begin
    require File.join(File.dirname(__FILE__), "config.rb")
    config_defaults.merge!(PREYFETCHER_CONFIG_RB)
  rescue LoadError # No config.rb found
    puts "No config.rb found; continuing on using Prey Fetcher defaults."
  end
  
  # Local-specific/not-git-managed config
  begin
    require File.join(File.dirname(__FILE__), "config-local.rb")
    config_defaults.merge!(PREYFETCHER_CONFIG_LOCAL_RB)
  rescue LoadError # No config.rb found
    puts "No config-local.rb found; nothing exported."
  end
  
  # Same deal with config-production.rb
  if Sinatra::Application.environment == :production
    begin
      require File.join(File.dirname(__FILE__), "config-production.rb")
      config_defaults.merge!(PREYFETCHER_CONFIG_PRODUCTION_RB)
    rescue LoadError # No config-production.rb found
      puts "No config-production.rb found; continuing on using Prey Fetcher defaults."
    end
  end
  
  # Store our config stuff in this hash temporarily
  config = {}
  
  # Set our config keys based on environmental variables.
  # If they aren't present, fallback to config.rb/defaults.
  config_defaults.each do |key, default|
    from_env = ENV["PREYFETCHER_#{key.to_s.upcase}"]
    config[key] = (from_env) ? from_env : default
  end
  
  # Assemble some extra config values from those already set
  config[:app_url] = "http://#{config[:app_domain]}"
  config[:app_version] = PREYFETCHER_VERSION
  config[:app_user_agent] = "#{config[:app_name]} #{config[:app_version]} (#{config[:app_url]})"
  
  # Put it in a constant so it's not tampered with and so
  # it's globally accessible
  PREYFETCHER_CONFIG = config
  
  # Database stuff
  unless PREYFETCHER_CONFIG[:db_adapter] == 'sqlite3'
    DataMapper.setup(:default, "#{PREYFETCHER_CONFIG[:db_adapter]}://#{PREYFETCHER_CONFIG[:db_username]}:#{PREYFETCHER_CONFIG[:db_password]}@#{PREYFETCHER_CONFIG[:db_host]}/#{PREYFETCHER_CONFIG[:db_database]}")
  else
    DataMapper.setup(:default, "sqlite3:#{PREYFETCHER_CONFIG[:db_database]}")
  end
end

helpers do
  # Return a link to an asset file on another domain.
  def asset(file)
    "http://#{PREYFETCHER_CONFIG[:app_asset_domain]}/#{file}"
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
  :consumer_key => PREYFETCHER_CONFIG[:twitter_consumer_key],
  :secret => PREYFETCHER_CONFIG[:twitter_consumer_secret]
helpers Twitter::Login::Helpers

# Index action -- show the homepage.
get "/" do
  # Index page is the entry point after login/signup
  if twitter_user
    unless session[:logged_in]
      flash[:notice] = "Logged into Prey Fetcher as <span class=\"underline\">@#{twitter_user.screen_name}</span>."
      session[:logged_in] = true
    end
    
    if User.count(:twitter_user_id => twitter_user.id) == 0
      @user = User.create_from_twitter(twitter_user, session[:twitter_access_token][0], session[:twitter_access_token][1])
      flash[:notice] = "Created Prey Fetcher account for @#{twitter_user.screen_name}.<br><a href=\"#user_prowl_api_key\">Enter your Prowl API key</a> to enable notifications."
    end
    
    # The homepage is useless to logged-in users; show them their account instead
    redirect '/account'
  end
  
  @title = "Instant Twitter Notifications for iOS"
  erb :index
end

# Show the FAQ.
get "/about" do
  @title = "About Prey Fetcher"
  erb :about
end

# Show the feature list.
get "/features" do
  @title = "Features"
  erb :features
end

# Show the Privacy jazz.
get "/privacy" do
  @title = "Privacy"
  erb :privacy
end

# Show the OSS page.
get "/open-source" do
  @title = "Open Source"
  erb :open_source
end

# Show account info.
get "/account" do
  redirect '/' unless twitter_user
  
  @title = "Account and Notification Settings"
  @user = User.first(:twitter_user_id => twitter_user.id)
  erb :account
end

# Receive new account settings.
put "/account" do
  redirect '/' unless twitter_user
  
  @user = User.first(:twitter_user_id => twitter_user.id)
  settings = {}
  
  # Hack to prevent mass assignment
  User.mass_assignable.each do |a|
    settings[a] = params[:user][a]
  end
  
  # Hotfix for list bug
  settings.delete(:notification_list) if settings[:notification_list] && settings[:notification_list].blank?
  
  if @user.update(settings)
    flash[:notice] = "Your account and notification settings have been updated."
    redirect '/account'
  else
    flash.now[:alert] = "Sorry, but your account couldn't be updated.<br><ul>"
    @user.errors.each do |e|
      flash.now[:alert] << "<li>#{e}</li>"
    end
    flash.now[:alert] << "</ul>"
    @title = "Account and Notification Settings"
    erb :account
  end
end

# Delete user account
delete "/account" do
  redirect '/' unless twitter_user
  
  @user = User.first(:twitter_user_id => twitter_user.id)
  @user.destroy!
  
  flash[:notice] = "Your Prey Fetcher account (for <span class=\"underline\">@#{twitter_user.screen_name}</span>) has been deleted.<br />Sorry to see you go!"
  twitter_logout
  session[:logged_in] = false
  redirect '/'
end

# Put request that updates a user's lists from Twitter.
put "/lists" do
  @user = User.first(:twitter_user_id => twitter_user.id)
  if @user
    @user.lists(true)
    flash[:notice] = "Your Twitter lists have been updated."
    redirect '/account'
  else
    flash[:error] = "No user matching your Twitter account was found."
    redirect '/'
  end
end

# Logout and remove any session data.
get "/logout" do
  redirect '/' unless twitter_user
  
  flash[:notice] = "Logged <span class=\"underline\">@#{twitter_user.screen_name}</span> out of Prey Fetcher."
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
