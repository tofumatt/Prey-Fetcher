class User < ActiveRecord::Base
  
  PRIORITY_RANGE = -1..2
  
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
  
  def self.create_user_from_twitter(twitter_user, session)
    # Create a local User record if one doesn't exist already
    if !User.exists?(:twitter_user_id => twitter_user.id)
      user = User.new( # Fill in the params manually; we only need a few settings
        :twitter_user_id => twitter_user.id,
        :twitter_username => twitter_user.screen_name,
        :access_key => session[:access_token][0],
        :access_secret => session[:access_token][1],
        :protected => twitter_user.protected
      )
      
      # Save the record, so now we can do lookups on this user
      user.save(false)
    else
      user = nil
    end
    
    user
  end
  
  def self.human_attribute_name(attr)
    HUMANIZED_ATTRIBUTES[attr.to_sym] || super
  end
  
  def prowl_api_key_is_valid
    logger.debug Time.now.to_s
    logger.debug 'Validating a Prowl API Key...'
    
    if self.prowl_api_key.blank?
      errors.add(:prowl_api_key, " is blank. You need to supply an API Key.")
    elsif !Prowl.verify(self.prowl_api_key)
      errors.add(:prowl_api_key, " you submitted isn't valid.")
    end
  end
  
  def process_response(tweet_type, prowl)
    # Send any DM notifications -- handle exceptions from the JSON parser in case
    # Twitter sends us back malformed JSON or (more likely) HTML when it's over capacity
    begin
      request, priority, since_id, sender = (tweet_type == "DM") ? [@dm_request, self.dm_priority, self.dm_since_id, 'sender'] : [@mention_request, self.mention_priority, self.mention_since_id, 'user']
      tweets = JSON.parse(request.response.body)
      if tweets.size > 0
        # The notification text depends on the number of new tweets
        if tweets.size == 1
          event = "From @#{tweets.first[sender]['screen_name']}"
          description = tweets.first['text']
        elsif tweets.size == 11
          event = "Over 10 #{tweet_type}s! Latest from @#{tweets.first[sender]['screen_name']}"
          description = tweets.first['text']
        else
          event = "#{tweets.size} #{tweet_type}s. Latest from @#{tweets.first[sender]['screen_name']}"
          description = tweets.first['text']
        end
        
        # Update this users's since_id
        update_attribute("#{tweet_type.downcase}_since_id", tweets.first['id'])
        
        # A since_id of 1 means the user is brand new -- we don't send notifications on the first check
        if since_id > 1
          prowl.add(:application => APPNAME + ' ' + tweet_type, :apikey => self.prowl_api_key, :priority => priority, :event => event, :description => description)
          Notification.new(:twitter_user_id => self.twitter_user_id).save
        end
      end
    rescue JSON::ParserError # Bad data (probably not even JSON) returned for this response
      logger.error Time.now.to_s + '   @' + self.twitter_username
      logger.error 'Twitter was over capacity for @' + self.twitter_username + '? Couldn\'t make a usable array from JSON data.'
    rescue Exception # Bad data or some other weird response
      logger.error Time.now.to_s + '   @' + self.twitter_username
      logger.error 'Error getting data for @' + self.twitter_username + '. Twitter probably returned bad data.'
    end
  end
  
  def check_dms
    uri = 'https://twitter.com/direct_messages.json'
    params = {
      'count' => 11,
      'since_id' => self.dm_since_id,
      'prey_fetcher_twitterid' => self.twitter_user_id
    }
    
    @dm_request = Typhoeus::Request.new(uri,
      :user_agent => USER_AGENT,
      :method => :get,
      :headers => { :Authorization => SOAuth.header(uri, oauth, params) },
      :params => params
    )
    
    # Return the request object (usually to Hydra)
    @dm_request
  end
  
  def check_mentions
    uri = 'https://twitter.com/statuses/mentions.json'
    params = {
      'count' => 11,
      'since_id' => self.mention_since_id,
      'prey_fetcher_twitterid' => self.twitter_user_id
    }
    
    @mention_request = Typhoeus::Request.new(uri,
      :user_agent => USER_AGENT,
      :method => :get,
      :headers => { :Authorization => SOAuth.header(uri, oauth, params) },
      :params => params
    )
    
    # Return the request object (usually to Hydra)
    @mention_request
  end
  
  # Method called by cron to check all user accounts for new DMs and
  # mentions, then send any notifications to Prowl
  def self.check_twitter
    require 'fastprowl'
    require 'soauth'
    
    hydra = Typhoeus::Hydra.new(:max_concurrency => MAX_CONCURRENCY)
    prowl = Prowl.new(
      :application => APPNAME,
      :providerkey => PROWL_PROVIDER_KEY
    )
    users = User.all
    
    # Loop through all users and queue all requests to Twitter in Hydra
    users.each do |u|
      # If the user doesn't have an API key we won't do anything
      hydra.queue(u.check_dms) if u.enable_dms && !u.prowl_api_key.blank?
    end
    
    # Run all the requests
    hydra.run
    
    # Loop through each user again, sending Prowl notifications if necessary
    users.each do |u|
      # Again, skip users with no key
      u.process_response('DM', prowl) if u.enable_dms && !u.prowl_api_key.blank?
    end
    
    # Send all the prowl notifications
    prowl.run
  end
  
  protected
  
  def oauth
    {
      :consumer_key => OAUTH_SETTINGS['consumer_key'],
      :consumer_secret => OAUTH_SETTINGS['consumer_secret'],
      :token => self.access_key,
      :token_secret => self.access_secret
    }
  end
  
end
