require "rubygems"
require "bundler"
require "yaml"
Bundler.setup

Bundler.require

# Set Sinatra's variables
set :app_file, __FILE__
set :environment, (ENV['RACK_ENV']) ? ENV['RACK_ENV'].to_sym : :development
set :root, File.dirname(__FILE__)
set :public, "public"
set :views, "views"

# House internal methods and junk inside our own namespace
module PreyFetcher
  # Houses app config options loaded from defaults, environment variables,
  # and various cascading config files.
  @@_config = nil
  
  # Static route => title matching for simple, static pages on the site
  # that don't require much in the way of controllers.
  STATIC_PAGES = {
    :about => "About Prey Fetcher",
    :features => "Features",
    :privacy => "Privacy",
    :open_source => "Open Source"
  }
  
  # Current version number + prefix. Gets used in
  # as the User Agent in REST/Streaming requests.
  VERSION = "4.9"
  
  # Return a requested config value or nil if the value is nil/doesn't exist.
  def self.config(option)
    @@_config[option.to_s]
  end
  
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
  
  # This is a hack; I need to rewrite FastProwl to allow it to be more
  # flexible. Until such a time; this goes here.
  def self.retrieve_apikey(token)
    response = Typhoeus::Request.get('https://prowlapp.com/publicapi/retrieve/apikey',
      :user_agent => PreyFetcher.config(:app_user_agent),
      :params => {
        :providerkey => PreyFetcher.config(:app_prowl_provider_key),
        :token => token
      }
    )
    
    if response.code == 200
      Nokogiri::XML.parse(response.body).xpath('//retrieve').attr('apikey').value
    else
      false
    end
  end
  
  # This is a hack too; I need to rewrite FastProwl to allow it to be more
  # flexible. Until such a time; this goes here.
  def self.retrieve_token
    response = Typhoeus::Request.get('https://prowlapp.com/publicapi/retrieve/token',
      :user_agent => PreyFetcher.config(:app_user_agent),
      :params => {:providerkey => PreyFetcher.config(:app_prowl_provider_key)}
    )
    
    if response.code == 200
      {
        :token => Nokogiri::XML.parse(response.body).xpath('//retrieve').attr('token').value,
        :url => Nokogiri::XML.parse(response.body).xpath('//retrieve').attr('url').value,
      }
    else
      false
    end
  end
  
  # Assign configuration to Prey Fetcher from a hash. Config should not be modified
  # after it is set.
  def self.set_config!(config)
    @@_config = config unless @@_config
  end
end

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

# An account is a collection of Users used to login to the web interface.
class Account
  include DataMapper::Resource
  include DataMapper::Validate
  
  property :id, Serial
  property :name, String
  property :custom_url, String
  property :prowl_api_key, String
  # Timestamps
  property :created_at, DateTime
  property :updated_at, DateTime
  
  has n, :users
  
  before :save, :url_has_protocol?
  validates_with_method :prowl_api_key, :method => :prowl_api_key_is_valid?
  
  # Return a list of values we allow routes to mass-assign
  # to an Account.
  def self.mass_assignable
    [
      :name,
      :custom_url,
      :prowl_api_key
    ]
  end
  
  # Test an account's Prowl API key via the Prowl API.
  def prowl_api_key_is_valid?
    return [false, "You must supply a Prowl API key."] if self.prowl_api_key.nil? || self.prowl_api_key.blank?
    
    if FastProwl.verify(self.prowl_api_key)
      true
    else
      [false, "The Prowl API key you supplied was invalid."]
    end
  end
  
  # Run this validation to make sure the supplied URL is valid (if
  # it's not, just convert it to a valid URL automatically).
  def url_has_protocol?
    # If the URL doesn't have a colon we assume a lack of protocol
    # and use http://
    # 
    # Try to catch obviously bad URLs, but we can't test for everything
    unless self.custom_url.blank? || self.custom_url.match(/:/)
      self.custom_url = 'http://' + self.custom_url
    end
    
    # Catch basic empty URLs
    self.custom_url = nil if self.custom_url == 'http://'
  end
end

# Record of when a notification, including the user record it relates
# to, when it was sent, and the item associated with it.
class Notification
  include DataMapper::Resource
  
  # Constants representing the type of notification delivered.
  TYPE_DM = 1
  TYPE_LIST = 2
  TYPE_MENTION = 3
  TYPE_RETWEET = 4
  TYPE_FAVORITE = 5
  
  property :id, Serial
  property :twitter_user_id, Integer
  property :type, Integer
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
  property :access_key, String
  property :access_secret, String
  property :account_id, Integer
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
  # Favourites
  property :enable_favorites, Boolean, :default => false
  property :favorites_priority, Integer, :default => 0
  # Timestamps
  property :created_at, DateTime
  property :updated_at, DateTime
  
  belongs_to :account
  has n, :notifications
  
  # Create a new user from session data retrieved from
  # twitter-login/OAuth authorization.
  def self.create_from_twitter(twitter_user, access_key, access_token, account_id = nil)
    # Create a new Account if no account_id was specified.
    if account_id.nil?
      account = Account.create!(
        :name => twitter_user.screen_name,
        :created_at => Time.now,
        :updated_at => Time.now
      )
      
      account_id = account.id
    end
    
    User.create!( # Fill in the params manually; we only need a few settings
      :twitter_user_id => twitter_user.id,
      :twitter_username => twitter_user.screen_name,
      :access_key => access_key,
      :access_secret => access_token,
      # Account id from either a function argument or a newly-created record
      :account_id => account_id,
      # Because we ignore callbacks
      :created_at => Time.now,
      :updated_at => Time.now
    )
    
    # Load the user from the DB and try to set their since_ids
    user = User.first(:twitter_user_id => twitter_user.id)
    
    # If we can't get the data, it's OK. But it's nicer to set
    # this stuff on account creation.
    PreyFetcher::protect_from_twitter do
      direct_messages = Twitter::Base.new(user.oauth).direct_messages(:count => 1)
      user.update!(:dm_since_id => direct_messages.first['id']) if direct_messages.size > 0
      
      mentions = Twitter::Base.new(user.oauth).mentions(:count => 1)
      user.update!(:mention_since_id => mentions.first['id']) if mentions.size > 0
    end
    
    # Write this user to our stream track file so we start tracking them.
    f = File.open(File.join('tmp', 'stream-users.add'), File::RDWR|File::CREAT)
    f.flock File::LOCK_EX
    f.write(twitter_user.id.to_s + "\n")
    f.flock File::LOCK_UN
    f.close
  end
  
  # Return a list of values we allow routes to mass-assign
  # to a User.
  def self.mass_assignable
    [
      :enable_mentions,
      :mention_priority,
      :disable_retweets,
      :retweet_priority,
      :enable_dms,
      :dm_priority,
      :enable_list,
      :notification_list,
      :list_priority,
      :enable_favorites,
      :favorites_priority
    ]
  end
  
  # Return users who share the same API keys as this user
  def accounts
    (account) ? account.users : nil
  end
  
  # Check Twitter for new tweets for any lists Prey Fetcher
  # checks for this user using the REST API.
  def check_lists
    PreyFetcher::protect_from_twitter do
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
  
  # Return this user's custom URL redirect
  def custom_url
    account.custom_url
  end
  
  # Return the opposite of "disable_retweets"; here for convenience, as Matt
  # stupidly classed retweets as a subset of mentions at first.
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
    PreyFetcher::protect_from_twitter do
      lists = Twitter::Base.new(oauth).lists(twitter_username).lists
      
      update!(:lists_serialized => lists)
      
      list_ids = []
      lists.each do |list|
        list_ids << list.id
      end
      
      # Remove the list this user was
      # following if it no longer exists
      update!(:notification_list => nil) unless lists.size > 0 and list_ids.include?(notification_list)
    end
    
    lists
  end
  
  # Check to see if this user has multiple accounts with the same Prowl
  # API key.
  def multiple_accounts?
    (accounts.count > 1)
  end
  
  # Return this user's OAuth instance.
  def oauth
    if @oauth.nil?
      @oauth = Twitter::OAuth.new(PreyFetcher::config(:twitter_consumer_key), PreyFetcher::config(:twitter_consumer_secret))
      @oauth.authorize_from_access(access_key, access_secret)
    end
    
    @oauth
  end
  
  # Return this user's Prowl API key
  def prowl_api_key
    account.prowl_api_key
  end
  
  # Send a DM notification to Prowl for this user.
  def send_dm(tweet)
    # Update this users's since_id
    update(:dm_since_id => tweet[:id])
    
    FastProwl.add(
      :application => PreyFetcher::config(:app_prowl_appname),
      :providerkey => PreyFetcher::config(:app_prowl_provider_key),
      :apikey => prowl_api_key,
      :priority => dm_priority,
      :event => "DM from @#{tweet[:from]}",
      :description => tweet[:text].unescaped,
      :url => (custom_url.blank?) ? nil : custom_url
    )
    Notification.create(:twitter_user_id => twitter_user_id, :type => Notification::TYPE_DM)
  end
  
  # Send a favourite notification to Prowl for this user.
  def send_favorite(tweet)
    FastProwl.add(
      :application => PreyFetcher::config(:app_prowl_appname),
      :providerkey => PreyFetcher::config(:app_prowl_provider_key),
      :apikey => prowl_api_key,
      :priority => list_priority,
      :event => "Favorited by @#{tweet[:from]}",
      :description => tweet[:text].unescaped,
      :url => (custom_url.blank?) ? nil : custom_url
    )
    Notification.create(:twitter_user_id => twitter_user_id, :type => Notification::TYPE_FAVORITE)
  end
  
  # Send a List notification to Prowl for this user.
  def send_list(tweet)
    # Update this users's since_id
    update(:list_since_id => tweet[:id])
    
    FastProwl.add(
      :application => PreyFetcher::config(:app_prowl_appname),
      :providerkey => PreyFetcher::config(:app_prowl_provider_key),
      :apikey => prowl_api_key,
      :priority => list_priority,
      :event => "List (newest: @#{tweet[:from]})",
      :description => tweet[:text].unescaped,
      :url => (custom_url.blank?) ? nil : custom_url
    )
    Notification.create(:twitter_user_id => twitter_user_id, :type => Notification::TYPE_LIST)
  end
  
  # Send a mention notification to Prowl for this user.
  def send_mention(tweet)
    # Update this users's since_id
    update(:mention_since_id => tweet[:id])
    
    FastProwl.add(
      :application => PreyFetcher::config(:app_prowl_appname),
      :providerkey => PreyFetcher::config(:app_prowl_provider_key),
      :apikey => prowl_api_key,
      :priority => mention_priority,
      :event => "Mention from @#{tweet[:from]}",
      :description => tweet[:text].unescaped,
      :url => (custom_url.blank?) ? nil : custom_url
    )
    Notification.create(:twitter_user_id => twitter_user_id, :type => Notification::TYPE_MENTION)
  end
  
  # Send a retweet notification to Prowl for this user.
  def send_retweet(tweet)
    # Update this users's since_id
    update(:retweet_since_id => tweet[:id])
    
    FastProwl.add(
      :application => PreyFetcher::config(:app_prowl_appname),
      :providerkey => PreyFetcher::config(:app_prowl_provider_key),
      :apikey => prowl_api_key,
      :priority => retweet_priority,
      :event => "Retweeted by @#{tweet[:from]}",
      :description => tweet[:text].unescaped,
      :url => (custom_url.blank?) ? nil : custom_url
    )
    Notification.create(:twitter_user_id => twitter_user_id, :type => Notification::TYPE_RETWEET)
  end
  
  # Test this user's OAuth credentials and update/verify their username.
  def verify_credentials
    PreyFetcher::protect_from_twitter do
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
  # Grab stuff from config.yaml -- it's _required_
  config = YAML.load(File.open(File.join(File.dirname(__FILE__), "config.yaml"), File::RDONLY).read)
  
  # Local-specific/not-git-managed config
  begin
    config.merge!(YAML.load(File.open(File.join(File.dirname(__FILE__), "config_local.yaml"), File::RDONLY).read))
  rescue Errno::ENOENT # No config_local.yaml found
    puts "No config_local.yaml found; you need to install one from config_local.dist.yaml to use most of Prey Fetcher's features."
  end
  
  # Assemble some extra config values from those already set
  config['app_url'] = "http://#{config['app_domain']}"
  config['app_version'] = PreyFetcher::VERSION
  config['app_user_agent'] = "#{config['app_name']} #{config['app_version']} " + ((Sinatra::Application.environment == :production) ? "(#{config['app_url']})" : "(DEVELOPMENT VERSION)")
  
  # Put it in the Prey Fetcher module so it's not tampered with
  # and is globally accessible.
  PreyFetcher::set_config!(config)
  
  # Database stuff.
  unless PreyFetcher::config(:db_adapter) == 'sqlite3'
    DataMapper.setup(:default, "#{PreyFetcher::config(:db_adapter)}://#{PreyFetcher::config(:db_username)}:#{PreyFetcher::config(:db_password)}@#{PreyFetcher::config(:db_host)}/#{PreyFetcher::config(:db_database)}")
  else
    DataMapper.setup(:default, "sqlite3:#{PreyFetcher::config(:db_database)}")
  end
  
  # Output the current version (to either log or stdout)
  puts "Booting and config'd #{PreyFetcher.config(:app_user_agent)}"
end

helpers do
  # Return a link to an asset file on another domain.
  def asset(file)
    "http://#{PreyFetcher::config(:app_asset_domain)}/#{file}?v=#{PreyFetcher::config(:app_version)}"
  end
  
  # Return the current user based on Prey Fetcher user id in session.
  def current_user
    if session && session[:current_user_id]
      User.get(session[:current_user_id])
    else
      nil
    end
  end
  
  # Return true if user is logged in.
  def logged_in?
    session && session[:logged_in]
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
  :consumer_key => PreyFetcher::config(:twitter_consumer_key),
  :secret => PreyFetcher::config(:twitter_consumer_secret)
helpers Twitter::Login::Helpers

# Index action -- show the homepage.
get "/" do
  # Index page is the entry point after login/signup
  if twitter_user
    if User.count(:twitter_user_id => twitter_user.id) == 0
      User.create_from_twitter(twitter_user, session[:twitter_access_token][0], session[:twitter_access_token][1], ((current_user) ? current_user.account_id : nil))
      flash[:notice] = "Created Prey Fetcher account for @#{twitter_user.screen_name}.<br>You can now customize your notification settings."
      
      @user = User.first(:twitter_user_id => twitter_user.id)
      
      # Set our login session data before we redirect to Prowl
      session[:current_account_id] = @user.account_id
      session[:current_user_id] = @user.id
      session[:logged_in] = true
      
      # Once we create a user we need their Prowl API Key, so start
      # the Prowl API Key request.
      redirect '/prowl-api-key' unless @user.multiple_accounts?
    end
    
    # Setup account/login state for existing user adding another account.
    if logged_in?
      previous_user = current_user
      user = User.first(:twitter_user_id => twitter_user.id)
      
      # Are we adding an existing Prey Fetcher user to this account?
      if previous_user.account_id != user.account_id
        user.update!(:account_id => previous_user.account_id)
        
        # Destroy the old Account this user has no accounts after the update.
        old_account = Account.get(user.account_id)
        if old_account.users.count == 0
          old_account.destroy!
        end
      end
      
      # Setup our session data for login state
      session[:current_account_id] = previous_user.account_id
      session[:current_user_id] = user.id
      session[:logged_in] = true
    else # Setup "login"/session state for a user who just logged in from Twitter.
      # Switch "current user" context to the twitter user we just logged in as.
      user = User.first(:twitter_user_id => twitter_user.id)
      
      flash[:notice] = "Logged into Prey Fetcher as <span class=\"underline\">@#{twitter_user.screen_name}</span>."
      
      # Setup our session data for login state
      session[:current_account_id] = user.account_id
      session[:current_user_id] = user.id
      session[:logged_in] = true
    end
    
    # The homepage is useless to logged-in users; show them their account instead
    redirect '/account'
  end
  
  # If there's no twitter_user we remove session data, just in case
  session.delete :account_account_id
  session.delete :current_account_id
  session[:logged_in] = false
  
  @title = "Instant Twitter Notifications for iOS"
  erb :index
end

# Generic, static pages.
PreyFetcher::STATIC_PAGES.each do |url, title|
  get "/#{url.to_s.gsub('_', '-')}" do
    @title = title
    erb url
  end
end

# This is the URL users who have authorized a Prowl API Key request
# are sent to after authorization. Use the stored token and our
# provider key to get a new API key for this user and store it in
# their account.
get "/api-key" do
  redirect '/' unless logged_in? && session[:token]
  
  apikey = PreyFetcher.retrieve_apikey(session[:token][:token])
  
  if apikey
    @user = current_user
    @user.account.update({:prowl_api_key => apikey})
  else
    flash[:alert] = "Authorization with Prowl API denied. You can <a href=\"/prowl-api-key\">try again</a> if you denied access by mistake."
  end
  
  redirect '/account'
end

# Get a Prowl API key retrieval token and redirect the user
# to the Prowl authorization page.
get "/prowl-api-key" do
  redirect '/' unless logged_in?
  
  session[:token] = PreyFetcher.retrieve_token
  
  if session[:token]
    redirect session[:token][:url]
  else
    flash[:alert] = "Couldn't communicate with the Prowl API. Try again or <a href=\"http://twitter.com/preyfetcher\">contact @preyfetcher</a>."
    redirect '/account'
  end
end

# Show account info.
get "/account" do
  redirect '/' unless logged_in?
  
  @title = "Account and Notification Settings"
  @user = current_user
  erb :account
end

# Add a new user record to an existing account.
post "/account" do
  redirect '/' unless logged_in?
  
  # Remove current twitter user from session
  twitter_logout
  
  # Setup an OAuth Consumer object similar to the one
  # Twitter::Login uses.
  consumer = Twitter::OAuth.new(
    PreyFetcher::config(:twitter_consumer_key),
    PreyFetcher::config(:twitter_consumer_secret),
    :site => 'https://api.twitter.com',
    :authorize_path => '/oauth/authenticate'
  )
  
  # Get a request token and store it in the session so
  # the login middleware can use it after the redirect
  # from Twitter's API.
  request_token = consumer.request_token(
    :force_login => 'true',
    :oauth_callback => "#{PreyFetcher::config(:app_url)}/login"
  )
  session[:twitter_request_token] = [request_token.token, request_token.secret]
  
  # Off to Twitter!
  redirect request_token.authorize_url
end

# Receive new account settings.
put "/account" do
  redirect '/' unless logged_in?
  
  @user = current_user
  account_settings, settings = {}, {}
  
  # Hack to prevent mass assignment
  Account.mass_assignable.each do |a|
    account_settings[a] = params[:account][a]
  end
  
  # Hack to prevent mass assignment
  User.mass_assignable.each do |a|
    settings[a] = params[:user][a]
  end
  
  # Hotfix for list bug
  settings.delete(:notification_list) if settings[:notification_list] && settings[:notification_list].blank?
  
  if @user.account.update(account_settings) && @user.update(settings)
    flash[:notice] = "Your account and notification settings have been updated."
    redirect '/account'
  else
    flash.now[:alert] = "Sorry, but your account couldn't be updated.<br><ul>"
    
    if @user.account.errors
      @user.account.errors.each do |e|
        flash.now[:alert] << "<li>#{e}</li>"
      end
    end
    
    if @user.errors
      @user.errors.each do |e|
        flash.now[:alert] << "<li>#{e}</li>"
      end
    end
    flash.now[:alert] << "</ul>"
    
    @title = "Account and Notification Settings"
    erb :account
  end
end

# Delete user account
delete "/account" do
  redirect '/' unless logged_in?
  
  @user = current_user
  @user.destroy!
  
  flash[:notice] = "Your Prey Fetcher account (for <span class=\"underline\">@#{twitter_user.screen_name}</span>) has been deleted.<br />Sorry to see you go!"
  twitter_logout
  session[:logged_in] = false
  redirect '/'
end

# Switch the currently active (Twitter) account for this user.
put "/account-switch" do
  redirect '/' unless logged_in? && !params[:id].blank?
  
  # Get the user we're going to try to switch to.
  new_user = User.get(params[:id].to_i)
  
  # Check to see if this user is related to the ID being requested.
  # We relate users to each other by Prowl API keys.
  if new_user && current_user.account.id == new_user.account.id
    session[:current_user_id] = new_user.id
    flash[:notice] = "Switched to @#{new_user.twitter_username}."
  else
    flash[:error] = "Can't switch to that user. You are still logged in as @#{current_user.twitter_username}."
  end
  
  redirect '/account'
end

# Put request that updates a user's lists from Twitter.
put "/lists" do
  @user = current_user
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
  redirect '/' unless logged_in?
  
  flash[:notice] = "Logged <span class=\"underline\">@#{twitter_user.screen_name}</span> out of Prey Fetcher."
  twitter_logout
  session.delete :current_user_id
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
