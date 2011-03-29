require File.join(File.dirname(__FILE__), 'prey_fetcher.rb')
require "sinatra"

# Set Sinatra's variables
set :app_file, __FILE__
set :environment, (ENV['RACK_ENV']) ? ENV['RACK_ENV'].to_sym : :development
set :root, File.dirname(__FILE__)
set :public, "public"
set :views, "views"

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
