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
  # Handle newly created groups
  track_users[user_group] = [] if track_users[user_group].nil?
  
  # Add this user id to the current group and increnment our counters
  track_users[user_group] << user.twitter_user_id
  user_group_i += 1
  if user_group_i >= PreyFetcher::config(:twitter_site_stream_size)
    user_group += 1
    user_group_i = 1
  end
end

EventMachine.kqueue = true if EventMachine.kqueue? # file watching requires kqueue on OSX

module PreyFetcher
  @@_streams = []
  
  def self.add_stream(stream)
    @@_streams << stream
  end
  
  # Check to see if this tweet has all, or most, of the earmarks of
  # a spam tweet. Spam has become a serious issue on Twitter over
  # the past week (this code committed on Feb. 23, 2011) and this
  # should hopefully cut down on iPhones buzzing from Nike spam bots.
  def self.is_spam?(tweet)
    # Don't check anything if we don't have the right keys to operate on
    return false unless tweet['message'] && tweet['message']['user'] && tweet['message']['user']['followers_count'] && tweet['message']['user']['friends_count'] && tweet['message']['user']['profile_image_url'] && tweet['message']['user']['created_at'] && tweet['message']['entities'] && tweet['message']['entities']['urls']
    
    # Start with zero offences; tweets are innocent until proven guilty.
    offenses = 0
    
    # Check for accounts created recently. Spammers are smart and
    # usually create accounts then use them a few days later, so we
    # assume accounts that are [X] days ago are bad. This is a settable
    # config option but the default is 4.
    if Chronic.parse(tweet['message']['user']['created_at']) > Chronic.parse("#{PreyFetcher::config(:spam_days_ago_for_spam_accounts)} days ago")
      offenses += 1
      
      # If the account was created today it's even more suspicious. Sorry new users!
      if Chronic.parse(tweet['message']['user']['created_at']) > Chronic.parse('today')
        offenses += 1
      end
      
      # If a tweet from a user that new has exactly one link it's a bad sign too.
      if tweet['message']['entities']['urls'].count == 1
        offenses += 1
      end
      
      # Not many friends? Suspicious.
      if tweet['message']['user']['followers_count'] < PreyFetcher::config(:spam_low_followers_count)
        offenses += 1
      end
    end
    
    # If they're using the default profile image that's also a bad sign.
    if tweet['message']['user']['profile_image_url'].match('default_profile')
      offenses += 1
    end
    
    # No friends? No fun.
    if tweet['message']['user']['followers_count'] == 0
      offenses += 1
    end
    
    # If their friends ratio is one-sided, that's a good sign of spam.
    if tweet['message']['user']['followers_count'] <= (tweet['message']['user']['friends_count'] / 20).to_i
      offenses += 1
    end
    
    # If there's enough signs of spam, we should ignore this tweet.
    offenses >= PreyFetcher::config(:spam_max_offenses)
  end
  
  # Stop all Prey Fetcher streams and remove the stream-process file.
  def self.stop_streams!
    PreyFetcher::streams.each do |s|
      s.stop!
    end
    
    File.delete(File.join('tmp', 'stream-process.pid'))
  end
  
  def self.streams
    @@_streams
  end
  
  def self.trackNewUser(user_id)
    if PreyFetcher::streams.last.user_ids.count >= PreyFetcher::config(:twitter_site_stream_size)
      stream = PreyFetcher::SiteStream.new([user_id])
      PreyFetcher::add_stream(stream)
    else
      PreyFetcher::streams.last.add_user(user_id)
    end
  end
  
  # Watch a file for new user_ids to add to the least-crowded stream
  module FileHandler
    def file_modified
      return if File.zero?(path)
      puts "#{path} modified"
      
      user_ids_to_add = [];
      f = File.open(path, File::RDWR|File::CREAT)
      f.flock File::LOCK_EX
      
      f.each_line do |line|
        user_ids_to_add << line.to_i
      end
      
      user_ids_to_add.each do |id|
        PreyFetcher::trackNewUser(id)
      end
      
      # Zero out all users added to the file
      f.truncate(0)
      f.flock File::LOCK_UN
      f.close
      
      PreyFetcher::streams.last.restart!
    end
    
    def file_moved
      puts "#{path} moved"
    end
    
    def unbind
      puts "#{path} monitoring ceased"
    end
  end
  
  # Watch files in Prey Fetcher's tmp/ directory to know when to delete streams.
  module PIDFileHandler
    def file_moved
      puts "#{path} moved"
      
      File.delete(File.join('tmp', 'stream-users.add'))
      EventMachine.stop if EventMachine.reactor_running?
    end
    
    def file_deleted
      puts "#{path} deleted"
      
      File.delete(File.join('tmp', 'stream-users.add'))
      EventMachine.stop if EventMachine.reactor_running?
    end
    
    def unbind
      puts "#{path} monitoring ceased"
    end
  end
  
  # SiteStream is a class that contains a Twitter::JSONStream instance
  # to be run inside an EventMachine::run block. It provides functionality
  # for adding users to the stream, starting/stopping/restarting the stream, etc.
  class SiteStream
    # Deliver a tweet parsed from SiteStreams response.
    def self.deliver(tweet)
      unless ENV['RACK_ENV'] == 'production'
        puts ''
        puts tweet.inspect
        puts ''
      end
      
      # Skip if this tweet is bad or not available
      return if !tweet || tweet['for_user'].nil? || tweet['for_user'].blank?
      
      # Get the user this message belongs to
      user = User.first(:twitter_user_id => tweet['for_user'])
      
      # If we didn't find any users (they were deleted?), move on.
      return if user.nil?
      
      # Is this a direct message?
      if tweet['message'] && tweet['message']['direct_message'] && tweet['message']['direct_message']['recipient']['id'] == user.twitter_user_id
        if user.enable_dms
          user.send_dm(
            :id => tweet['message']['direct_message']['id'],
            :from => tweet['message']['direct_message']['sender_screen_name'],
            :text => tweet['message']['direct_message']['text']
          )
        else
          # If DM notifications aren't enabled, mark the retweet
          # so users who enable this feature still have up-to-date
          # since ids.
          user.update(:dm_since_id => tweet['message']['direct_message']['id'])
        end
      end
      
      # Did someone favourite a tweet?
      if tweet['message'] && tweet['message']['event'] == 'favorite' && tweet['message']['target'] && tweet['message']['target']['id'] == user.twitter_user_id && tweet['message']['source'] && tweet['message']['source']['id'] != user.twitter_user_id # If this user is favouriting themselves, don't notify them.
        if user.enable_favorites
          user.send_favorite(
            :id => tweet['message']['target_object']['id'],
            :from => tweet['message']['source']['screen_name'],
            :text => tweet['message']['target_object']['text']
          )
        end
      end
      
      # Is this a mention? (Make sure it's not an old-style RT by checking for RT substring)
      if tweet['message'] && tweet['message']['entities'] && tweet['message']['entities']['user_mentions'] && tweet['message']['entities']['user_mentions'].detect { |m| m['id'] == user.twitter_user_id } && !tweet['message']['text'].retweet?
        # Make sure this isn't spam.
        unless PreyFetcher::is_spam?(tweet)
          if user.enable_mentions
            user.send_mention(
              :id => tweet['message']['id'],
              :from => tweet['message']['user']['screen_name'],
              :text => tweet['message']['text']
            )
          else
            # If mention notifications aren't enabled, mark the retweet
            # so users who enable this feature still have up-to-date
            # since ids.
            user.update(:mention_since_id => tweet['message']['id'])
          end
        end
      end
      
      # Is this a retweet?
      if tweet['message'] && ((tweet['message']['retweeted_status'] && tweet['message']['retweeted_status']['user']['id'] == user.twitter_user_id) || (tweet['message']['retweeted_status'].nil? && tweet['message']['text'] && tweet['message']['text'].retweet?))
        if user.enable_retweets
          user.send_retweet(
            :id => tweet['message']['id'],
            :from => tweet['message']['user']['screen_name'],
            :text => (tweet['message']['retweeted_status'].nil?) ? tweet['message']['text'] : tweet['message']['retweeted_status']['text']
          )
        else
          # If retweet notifications aren't enabled, mark the retweet
          # so users who enable this feature still have up-to-date
          # since ids.
          user.update(:retweet_since_id => tweet['message']['id'])
        end
      end
    end
    
    # Parse a JSON stream item (with exception handling for bad
    # JSON data) and return the result of JSON.parse (or false
    # if the parse failed).
    def self.parse_from_stream(stream_item)
      begin
        JSON.parse(stream_item)
      rescue JSON::ParserError => e # Bad data (probably not even JSON) returned for this response
        puts "STREAMING ERROR: " + Time.now.to_s
        puts "STREAMING ERROR: " + "Twitter was over capacity? Couldn't make a usable array from JSON data."
        puts "STREAMING ERROR: " + e.to_s
        puts ''
        
        false
      end
    end
    
    # Load user ids for this stream and start the Twitter::JSONStream connection.
    def initialize(user_ids)
      # Load Twitter ids for this stream
      @user_ids = user_ids
      
      start!
    end
    
    # Add a user id to the currently running stream
    def add_user(id)
      @user_ids << id
    end
    
    # Return the currently-tracked user ids for this stream.
    def current_user_ids
      @current_user_ids
    end
    
    # Restart the stream by stopping it and starting it again. Any new
    # user id changes will be reflected upon restart.
    def restart!
      stop!
      start!
    end
    
    # Start this stream with the user ids provided to the constructor, and any
    # user ids added since the last time this stream was started.
    def start!
      # Copy the current set of user ids to an array so we can know which user ids
      # haven't yet been tracked in this stream.
      @current_user_ids = @user_ids
      
      @stream = Twitter::JSONStream.connect(
        :host    => 'betastream.twitter.com',
        :path    => '/2b/site.json',
        :oauth   => {
          :consumer_key    => PreyFetcher::config(:twitter_consumer_key),
          :consumer_secret => PreyFetcher::config(:twitter_consumer_secret),
          :access_key      => PreyFetcher::config(:twitter_access_key),
          :access_secret   => PreyFetcher::config(:twitter_access_secret)
        },
        :method  => 'POST',
        :filters => @user_ids,
        :user_agent => PreyFetcher::config(:app_user_agent)
      )
      
      @stream.each_item do |item|
        tweet = SiteStream::parse_from_stream(item)
        
        SiteStream::deliver(tweet)
      end
      
      @stream.on_error do |message|
        puts message
      end
      
      @stream.on_max_reconnects do |timeout, retries|
      end
    end
    
    # Stop the currently running stream.
    def stop!
      @stream.stop
      @stream.close_connection
    end
    
    # Return the list of user ids this stream is watching.
    def user_ids
      @user_ids
    end
  end
end

# Setup a stream per 100 users
EventMachine::run do
  # Create and close our file handler for this stream.
  f = File.new(File.join('tmp', 'stream-process.pid'), File::RDWR|File::CREAT)
  f.close
  
  # Create and close our user id handler for this stream.
  f = File.new(File.join('tmp', 'stream-users.add'), File::RDWR|File::CREAT)
  f.close
  
  track_users.each_value do |group|
    stream = PreyFetcher::SiteStream.new(group)
    PreyFetcher::add_stream(stream)
  end
  
  ['INT', 'TERM'].each do |sig|
    trap(sig) do
      puts "#{sig} signal received: quitting streaming.rb"
      PreyFetcher::stop_streams!
    end
  end
  
  EventMachine.watch_file(File.join('tmp', 'stream-process.pid'), PreyFetcher::PIDFileHandler)
  EventMachine.watch_file(File.join('tmp', 'stream-users.add'), PreyFetcher::FileHandler)
end
