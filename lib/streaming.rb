require 'rubygems'

# Load ActiveRecord outside Rails
require 'active_record'
require File.join(File.dirname(__FILE__), '../config/prey_fetcher.rb')
require File.join(File.dirname(__FILE__), '../app/models/notification.rb')
require File.join(File.dirname(__FILE__), '../app/models/user.rb')
require 'yaml'

DATABASE_CONFIG = YAML::load(File.open(File.join(File.dirname(__FILE__), '../config/database.yml')))

def establish_connection(database)
  dbconfig = DATABASE_CONFIG
  #dbconfig['development'].merge!('database' => "#{DEVPATH}db/development.sqlite3")
  ActiveRecord::Base.establish_connection(dbconfig[database])
#  ActiveRecord::Base.logger = Logger.new(STDERR)
end

def remove_connection
  ActiveRecord::Base.remove_connection
end

environment = (ENV['ENVIRONMENT'].nil? or ENV['ENVIRONMENT'].blank?) ? 'production' : ENV['ENVIRONMENT']

establish_connection(environment)

require 'json'
require 'twitter/json_stream'

require 'fastprowl'

track_string = ''
prowl_users = []

User.all.each do |user|
  if user.enable_mentions
    prowl_users << {
      :id => user.twitter_user_id,
      :username => user.twitter_username,
      :prowl_key => user.prowl_api_key,
      :priority => user.mention_priority
    }
    
    track_string += "@#{user.twitter_username},"
  end
end

track_string.chop!

EventMachine::run do
  stream = Twitter::JSONStream.connect(
    :path    => '/1/statuses/filter.json',
    :auth    => "#{TWITTER_CREDENTIALS[:username]}:#{TWITTER_CREDENTIALS[:password]}",
    :method  => 'POST',
    :content => "track=#{track_string}",
    :user_agent => USER_AGENT
  )
  
  stream.each_item do |item|
    # Do someting with unparsed JSON item.
    tweet = JSON.parse(item)
    
    prowl_users.each do |user|
      if tweet['text'].index("@#{user[:username]}")
        FastProwl.add(
          :application => APPNAME + ' mention',
          :providerkey => PROWL_PROVIDER_KEY,
          :apikey => user[:prowl_key],
          :priority => user[:priority],
          :event => "From @#{tweet['user']['screen_name']}",
          :description => tweet['text']
        )
        
        Notification.new(:twitter_user_id => user[:id]).save
      end
    end
  end
  
  stream.on_error do |message|
    # No need to worry here. It might be an issue with Twitter. 
    # Log message for future reference. JSONStream will try to reconnect after a timeout.
  end
  
  stream.on_max_reconnects do |timeout, retries|
    # Something is wrong on your side. Send yourself an email.
  end
  
  trap('TERM') {
    stream.stop
    EventMachine.stop if EventMachine.reactor_running? 
  }
end
