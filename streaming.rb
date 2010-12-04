require 'rubygems'
require 'json'

# Load Prey Fetcher
require File.join(File.dirname(__FILE__), "prey_fetcher.rb")

# Patch the streaming library to use the "follow" parameter
# instead of "track" (required for Site Streams).
module Twitter
  class JSONStream
    protected
      # Normalized query hash of escaped string keys and escaped string values.
      # nil values are skipped. Uses "follow" instead of "track" in JSONStream.
      def params
        {'follow' => escape(@options[:filters].join(","))}
      end
  end
end

track_users = {}
user_group = 1
user_group_i = 1

User.all.each do |user|
  # Avoid tracking users who have nothing to track or can't be sent notifications
  next if user.prowl_api_key.nil? || user.prowl_api_key.blank? || [user.enable_dms, user.enable_mentions].include?(true) == false
  
  # Handle newly created groups
  track_users[user_group] = [] if track_users[user_group].nil?
  
  # Add this user id to the current group and increnment our counters
  track_users[user_group] << user.twitter_user_id
  user_group_i += 1
  if user_group_i >= PREYFETCHER_CONFIG[:twitter_site_stream_size]
    user_group += 1
    user_group_i = 1
  end
end

EventMachine::run do
  # Setup a stream per 100 users
  track_users.each_value do |users_group|
    stream = Twitter::JSONStream.connect(
      :host    => 'betastream.twitter.com',
      :path    => '/2b/site.json',
      :oauth   => {
        :consumer_key    => PREYFETCHER_CONFIG[:twitter_consumer_key],
        :consumer_secret => PREYFETCHER_CONFIG[:twitter_consumer_secret],
        :access_key      => PREYFETCHER_CONFIG[:twitter_access_key],
        :access_secret   => PREYFETCHER_CONFIG[:twitter_access_secret]
      },
      :method  => 'POST',
      :filters => users_group,
      :user_agent => PREYFETCHER_CONFIG[:app_user_agent]
    )
    
    stream.each_item do |item|
      begin
        tweet = JSON.parse(item)
        
        # Get the user this message belows to
        user = User.first(:twitter_user_id => tweet['for_user'])
        
        # Ignore Prowl-less users
        next if user.prowl_api_key.nil? || user.prowl_api_key.blank?
        
        # Is this a direct message?
        if user.enable_dms && tweet['message'] && tweet['message']['direct_message'] && tweet['message']['direct_message']['recipient']['id'] == user.twitter_user_id
          user.send_dm(
            :id => tweet['message']['direct_message']['id'],
            :from => tweet['message']['direct_message']['sender_screen_name'],
            :text => tweet['message']['direct_message']['text']
          )
        end
        
        # Is this a mention? (Make sure it's not an old-style RT by checking for RT substring)
        if user.enable_mentions && tweet['message'] && tweet['message']['entities'] && tweet['message']['entities']['user_mentions'] && tweet['message']['entities']['user_mentions'].detect { |m| m['id'] == user.twitter_user_id } && !tweet['message']['text'].retweet?
          user.send_mention(
            :id => tweet['message']['id'],
            :from => tweet['message']['user']['screen_name'],
            :text => tweet['message']['text']
          )
        end
        
        # Is this a retweet?
        if user.enable_retweets && tweet['message'] && ((tweet['message']['retweeted_status'] && tweet['message']['retweeted_status']['user']['id'] != user.id) || (tweet['message']['text'] && tweet['message']['text'].retweet?))
          user.send_retweet(
            :id => tweet['message']['id'],
            :from => tweet['message']['user']['screen_name'],
            :text => tweet['message']['text']
          )
        end
      rescue JSON::ParserError => e # Bad data (probably not even JSON) returned for this response
        puts "STREAMING ERROR: " + Time.now.to_s
        puts "STREAMING ERROR: " + "Twitter was over capacity? Couldn't make a usable array from JSON data."
        puts "STREAMING ERROR: " + e.to_s
        puts ''
      end
    end
    
    stream.on_error do |message|
      puts message
    end
    
    stream.on_max_reconnects do |timeout, retries|
    end
    
    trap('TERM') {
      stream.stop
      EventMachine.stop if EventMachine.reactor_running? 
    }
  end
end
