require 'rubygems'
require 'json'

# Load Prey Fetcher
require File.join(File.dirname(__FILE__), "prey_fetcher.rb")

# Patch the streaming library to use the "follow" parameter
# instead of "track".
module Twitter
  class JSONStream
    protected
      # Normalized query hash of escaped string keys and escaped string values
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
  if user_group_i >= AppConfig['twitter']['site_stream_size']
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
        :consumer_key    => AppConfig['twitter']['oauth']['consumer_key'],
        :consumer_secret => AppConfig['twitter']['oauth']['consumer_secret'],
        :access_key      => AppConfig['twitter']['oauth']['access_key'],
        :access_secret   => AppConfig['twitter']['oauth']['access_secret']
      },
      :method  => 'POST',
      :filters => users_group,
      :user_agent => AppConfig['app']['user_agent']
    )
    
    stream.each_item do |item|
      tweet = JSON.parse(item)
      
      # Get the user this message belows to
      user = User.first(:twitter_user_id => tweet['for_user'])
      
      # Ignore Prowl-less users
      next if user.prowl_api_key.nil? || user.prowl_api_key.blank?
      
      puts tweet.inspect
      
      # Is this a direct message?
      if user.enable_dms && tweet['message'] && tweet['message']['direct_message']
        FastProwl.add(
          :application => AppConfig['app']['name'] + ' DM',
          :providerkey => AppConfig['app']['prowl_provider_key'],
          :apikey => user.prowl_api_key,
          :priority => user.dm_priority,
          :event => "From @#{tweet['message']['direct_message']['sender_screen_name']}",
          :description => tweet['message']['direct_message']['text']
        )
        
        Notification.create(:twitter_user_id => user.id)
      end
      
      # Is this a mention?
      if user.enable_mentions && tweet['message'] && tweet['message']['text'] && tweet['message']['text'].downcase.index("@#{user.twitter_username.downcase}") && tweet['message']['user']['screen_name']
        FastProwl.add(
          :application => AppConfig['app']['name'] + ' mention',
          :providerkey => AppConfig['app']['prowl_provider_key'],
          :apikey => user.prowl_api_key,
          :priority => user.mention_priority,
          :event => "From @#{tweet['message']['user']['screen_name']}",
          :description => tweet['message']['text']
        )
        
        Notification.create(:twitter_user_id => user.id)
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
