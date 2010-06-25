class User < ActiveRecord::Base
  # Prowl priority range that Prey Fetcher supports
  PRIORITY_RANGE = -1..2
  
  # Pretty names for properties
  HUMANIZED_ATTRIBUTES = {
    :prowl_api_key => "Prowl API Key"
  }
  
  # Store lists from Twitter in a serialized field
  serialize :lists_serialized
  
  # Setup associations based on the user's Twitter id;
  # if they ever leave the site and return, their old
  # notifications will get included in their counts
  has_many :notifications, :primary_key => :twitter_user_id, :foreign_key => :twitter_user_id
  
  validate :prowl_api_key_is_valid
  validates_inclusion_of :dm_priority, :in => PRIORITY_RANGE
  validates_inclusion_of :mention_priority, :in => PRIORITY_RANGE
  validates_inclusion_of :list_priority, :in => PRIORITY_RANGE
  validates_presence_of :notification_list, :if => :enable_list, :message => 'must be selected. Please select a list to watch.'
  
  # Create a new user from session data retrieved from
  # twitter-login/OAuth authorization
  def self.create_user_from_twitter(twitter_user, session)
    # Create a local User record if one doesn't exist already
    if !User.exists?(:twitter_user_id => twitter_user.id)
      user = User.new( # Fill in the params manually; we only need a few settings
        :twitter_user_id => twitter_user.id,
        :twitter_username => twitter_user.screen_name,
        :access_key => session[:access_token][0],
        :access_secret => session[:access_token][1]
      )
      
      # Save the record, so now we can do lookups on this user
      user.save(false)
    else
      user = nil
    end
    
    user
  end
  
  # Called by cron, etc. to check all user accounts for new
  # tweets/direct messages, then send all notifications to Prowl
  def self.check_twitter
    require 'fastprowl'
    require 'twitter'
    
    #@@fastprowl = FastProwl.new(:providerkey => PROWL_PROVIDER_KEY)
    
    # Loop through all users and queue all requests to Twitter in Hydra
    User.all.each do |u|
      # If the user doesn't have an API key we won't do anything
      unless u.prowl_api_key.nil? || u.prowl_api_key.blank?
        u.check_dms if u.enable_dms
        u.check_lists if u.enable_list
      end
    end
    
    # Send all Prowl notifications
    #@@fastprowl.run
  end
  
  # Use our pretty names, if they exist
  def self.human_attribute_name(attr)
    HUMANIZED_ATTRIBUTES[attr.to_sym] || super
  end
  
  # Test each user's OAuth credentials and update/verify their username
  def self.verify_credentials
    require 'twitter'
    
    User.all.each do |u|
      begin
        oauth = Twitter::OAuth.new(OAUTH_SETTINGS['consumer_key'], OAUTH_SETTINGS['consumer_secret'])
        oauth.authorize_from_access(u.access_key, u.access_secret)
        
        creds = Twitter::Base.new(oauth).verify_credentials
        
        # Update user's screen name if they've changed it (prevents
        # users who changed their screen name from getting notifications
        # through the Streaming API)
        if u.twitter_username && u.twitter_username != creds['screen_name']
          logger.info "Updating screen name for \#id #{u.id}. Changing name from @#{u.twitter_username} to @#{creds['screen_name']}"
          u.update_attribute('twitter_username', creds['screen_name'])
          
          creds = nil
        end
      rescue Twitter::Unauthorized => e # Delete this user; they've revoked access
        logger.error Time.now.to_s + '   @' + u.twitter_username
        logger.error 'Access revoked for @' + u.twitter_username + ". Deleting Twitter user id " + u.twitter_user_id.to_s
        logger.error '@' + u.twitter_username + '   ' + e.to_s
        
        # Try to solve bug with @AviN456's account
        unless u.twitter_username == 'AviN456'
          u.delete
        end
      rescue JSON::ParserError # Bad data (probably not even JSON) returned for this response
        logger.error Time.now.to_s + '   @' + self.twitter_username
        logger.error 'Twitter was over capacity for @' + self.twitter_username + "? Couldn't make a usable array from JSON data."
      rescue Timeout::Error
        logger.error Time.now.to_s + '   @' + self.twitter_username
        logger.error 'Twitter timed out for @' + self.twitter_username + "."
      rescue Exception # Bad data or some other weird response
        logger.error Time.now.to_s + '   @' + self.twitter_username
        logger.error 'Error getting data for @' + self.twitter_username + '. Twitter probably returned bad data.'
      end
    end
  end
  
  # Check Twitter for new DMs for this user using the REST API
  def check_dms
    # Send any DM notifications -- handle exceptions from the JSON
    # parser in case Twitter sends us back malformed JSON or (more
    # likely) HTML when it's over capacity
    begin
      direct_messages = Twitter::Base.new(oauth).direct_messages :count => 11, :since_id => dm_since_id
      
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
        update_attribute('dm_since_id', direct_messages.first['id'])
        
        # A since_id of 1 means the user is brand new -- we don't send notifications on the first check
        if dm_since_id != 1
          FastProwl.add(
            :application => APPNAME + ' DM',
            :providerkey => PROWL_PROVIDER_KEY,
            :apikey => prowl_api_key,
            :priority => dm_priority,
            :event => event,
            :description => direct_messages.first['text']
          )
          Notification.create(:twitter_user_id => twitter_user_id)
        end
      end
    rescue JSON::ParserError => e # Bad data (probably not even JSON) returned for this response
      logger.error Time.now.to_s + '   @' + twitter_username
      logger.error 'Twitter was over capacity for @' + twitter_username + "? Couldn't make a usable array from JSON data."
      logger.error '@' + twitter_username + '   ' + e.to_s
    rescue Timeout::Error => e
      logger.error Time.now.to_s + '   @' + twitter_username
      logger.error 'Twitter timed out for @' + twitter_username + "."
      logger.error '@' + twitter_username + '   ' + e.to_s
    rescue Exception => e # Bad data or some other weird response
      logger.error Time.now.to_s + '   @' + twitter_username
      logger.error 'Error getting data for @' + twitter_username + '. Twitter probably returned bad data.'
      logger.error '@' + twitter_username + '   ' + e.to_s
    end
  end
  
  # Check Twitter for new tweets for any lists Prey Fetcher
  # checks for this user using the REST API
  def check_lists
    # Send any DM notifications -- handle exceptions from the JSON
    # parser in case Twitter sends us back malformed JSON or (more
    # likely) HTML when it's over capacity
    begin
      list_tweets = Twitter::Base.new(oauth).list_timeline twitter_username, notification_list, :count => 2, :since_id => list_since_id
      
      if list_tweets.size > 0
        # The notification event text depends on the number of new tweets
        if list_tweets.size == 1
          event = "New tweet by @#{list_tweets.first['user']['screen_name']}"
        else
          event = "New tweets; latest by @#{list_tweets.first['user']['screen_name']}"
        end
        
        # Update this users's since_id
        update_attribute('list_since_id', list_tweets.first['id'])
        
        # Queue up this notification
        FastProwl.add(
          :application => APPNAME + ' List',
          :providerkey => PROWL_PROVIDER_KEY,
          :apikey => prowl_api_key,
          :priority => list_priority,
          :event => event,
          :description => list_tweets.first['text']
        )
        Notification.create(:twitter_user_id => twitter_user_id)
      end
    rescue JSON::ParserError => e # Bad data (probably not even JSON)
      logger.error Time.now.to_s + '   @' + twitter_username
      logger.error 'Twitter was over capacity for @' + twitter_username + "? Couldn't make a usable array from JSON data."
      logger.error '@' + twitter_username + '   ' + e.to_s
    rescue Timeout::Error => e
      logger.error Time.now.to_s + '   @' + twitter_username
      logger.error 'Twitter timed out for @' + twitter_username + "."
      logger.error '@' + twitter_username + '   ' + e.to_s
    rescue Exception => e # Bad data or some other weird response
      logger.error Time.now.to_s + '   @' + twitter_username
      logger.error 'Error getting data for @' + twitter_username + '. Twitter probably returned bad data.'
      logger.error '@' + twitter_username + '   ' + e.to_s
    end
  end
  
  # Load this users' lists from the REST API, and update their
  # locally stored/serialized lists property
  def load_lists
    lists = Twitter::Base.new(oauth).lists(twitter_username).lists# + Twitter::Base.new(oauth).list_subscriptions(twitter_username).lists
    
    update_attribute('lists_serialized', lists)
    
    list_ids = []
    lists.each do |list|
      list_ids << list.id
    end
    
    # Remove the list this user was
    # following if it no longer exists
    update_attribute('notification_list', nil) unless lists.size > 0 and list_ids.include? notification_list
    
    lists
  end
  
  # Return lists this user owns, includes private lists
  def lists(force_reload=false)
    return load_lists if force_reload
    
    lists_serialized || load_lists
  end
  
  # Return this user's OAuth instance
  def oauth
    if @oauth.nil?
      @oauth = Twitter::OAuth.new(OAUTH_SETTINGS['consumer_key'], OAUTH_SETTINGS['consumer_secret'])
      @oauth.authorize_from_access(self.access_key, self.access_secret)
    end
    
    @oauth
  end
  
  # Test a user's Prowl API key via the Prowl API
  def prowl_api_key_is_valid
    require 'fastprowl'
    logger.debug Time.now.to_s
    logger.debug 'Validating a Prowl API Key...'
    
    if prowl_api_key.blank?
      errors.add(:prowl_api_key, " is blank. You need to supply an API Key.")
    elsif !FastProwl.verify(self.prowl_api_key)
      errors.add(:prowl_api_key, " you submitted isn't valid.")
    end
  end
end
