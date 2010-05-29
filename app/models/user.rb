class User < ActiveRecord::Base
  # Prowl priority range that Prey Fetcher supports
  PRIORITY_RANGE = -1..2
  
  # Pretty names for properties
  HUMANIZED_ATTRIBUTES = {
    :prowl_api_key => "Prowl API Key"
  }
  
  # Setup associations based on the user's Twitter id;
  # if they ever leave the site and return, their old
  # notifications will get included in their counts
  has_many :notifications, :primary_key => :twitter_user_id, :foreign_key => :twitter_user_id
  
  validate :prowl_api_key_is_valid
  validates_inclusion_of :dm_priority, :in => PRIORITY_RANGE
  validates_inclusion_of :mention_priority, :in => PRIORITY_RANGE
  
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
  
  # Use our pretty names, if they exist
  def self.human_attribute_name(attr)
    HUMANIZED_ATTRIBUTES[attr.to_sym] || super
  end
  
  # Test a user's Prowl API key via the Prowl API
  def prowl_api_key_is_valid
    require 'fastprowl'
    logger.debug Time.now.to_s
    logger.debug 'Validating a Prowl API Key...'
    
    if self.prowl_api_key.blank?
      errors.add(:prowl_api_key, " is blank. You need to supply an API Key.")
    elsif !FastProwl.verify(self.prowl_api_key)
      errors.add(:prowl_api_key, " you submitted isn't valid.")
    end
  end
  
  # Check Twitter for new DMs for this user using the REST API
  def check_dms
    # Send any DM notifications -- handle exceptions from the JSON parser in case
    # Twitter sends us back malformed JSON or (more likely) HTML when it's over capacity
    begin
      @oauth = Twitter::OAuth.new(OAUTH_SETTINGS['consumer_key'], OAUTH_SETTINGS['consumer_secret'])
      @oauth.authorize_from_access(self.access_key, self.access_secret)
      
      @direct_messages = Twitter::Base.new(@oauth).direct_messages :count => 11, :since_id => self.dm_since_id
      
      if @direct_messages.size > 0
        # The notification text depends on the number of new tweets
        if @direct_messages.size == 1
          event = "From @#{@direct_messages.first['sender']['screen_name']}"
          description = @direct_messages.first['text']
        elsif @direct_messages.size == 11
          event = "Over 10 DMs! Latest from @#{@direct_messages.first['sender']['screen_name']}"
          description = @direct_messages.first['text']
        else
          event = "#{@direct_messages.size} DMs. Latest from @#{@direct_messages.first['sender']['screen_name']}"
          description = @direct_messages.first['text']
        end
        
        # Update this users's since_id
        update_attribute('dm_since_id', @direct_messages.first['id'])
        
        # A since_id of 1 means the user is brand new -- we don't send notifications on the first check
        if self.dm_since_id != 1
          @@fastprowl.add(
            :application => APPNAME + ' DM',
            :apikey => self.prowl_api_key,
            :priority => self.dm_priority,
            :event => event,
            :description => description
          )
          Notification.new(:twitter_user_id => self.twitter_user_id).save
        end
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
  
  # Called by cron, etc. to check all user accounts for new
  # tweets/direct messages, then send all notifications to Prowl
  def self.check_twitter
    require 'fastprowl'
    require 'twitter'
    
    @@fastprowl = FastProwl.new(:providerkey => PROWL_PROVIDER_KEY)
    
    # Loop through all users and queue all requests to Twitter in Hydra
    User.all.each do |u|
      # If the user doesn't have an API key we won't do anything
      u.check_dms if u.enable_dms && !u.prowl_api_key.blank?
    end
    
    # Send all Prowl notifications
    @@fastprowl.run
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
        if u.twitter_username != creds['screen_name']
          logger.info "Updating screen name for \#id #{u.id}. Changing name from @#{u.twitter_username} to @#{creds['screen_name']}"
          u.update_attribute('twitter_username', creds['screen_name'])
          
          creds = nil
        end
      rescue Twitter::Unauthorized => e # Delete this user; they've revoked access
        logger.error Time.now.to_s + '   @' + u.twitter_username
        logger.error 'Access revoked for @' + u.twitter_username + ". Deleting Twitter user id " + u.twitter_user_id.to_s
        logger.error '@' + u.twitter_username + '   ' + e.to_s
        u.delete
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
end
