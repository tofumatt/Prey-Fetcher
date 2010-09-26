require 'rubygems'
require 'json'

# Load Prey Fetcher
require File.join(File.dirname(__FILE__), "prey_fetcher.rb")

prowl_users = []
track_users = []

User.all.each do |user|
  if user.enable_mentions
    prowl_users << {
      :id => user.twitter_user_id,
      :username => user.twitter_username,
      :prowl_key => user.prowl_api_key,
      :priority => user.mention_priority
    }
    
    track_users << "@#{user.twitter_username}"
  end
end

EventMachine::run do
  stream = Twitter::JSONStream.connect(
    :path    => '/1/statuses/filter.json',
    :oauth   => {
      :consumer_key    => AppConfig['twitter']['oauth']['consumer_key'],
      :consumer_secret => AppConfig['twitter']['oauth']['consumer_secret'],
      :access_key      => AppConfig['twitter']['oauth']['access_key'],
      :access_secret   => AppConfig['twitter']['oauth']['access_secret']
    },
    :method  => 'POST',
    :filters => track_users,
    :user_agent => AppConfig['app']['user_agent']
  )
  
  stream.each_item do |item|
    tweet = JSON.parse(item)
    
    prowl_users.each do |user|
      if tweet['text'].downcase.index("@#{user[:username].downcase}")
        FastProwl.add(
          :application => AppConfig['app']['name'] + ' mention',
          :providerkey => AppConfig['app']['prowl_provider_key'],
          :apikey => user[:prowl_key],
          :priority => user[:priority],
          :event => "From @#{tweet['user']['screen_name']}",
          :description => tweet['text']
        )
        
        Notification.create(:twitter_user_id => user[:id])
      end
    end
  end
  
  stream.on_error do |message|
  end
  
  stream.on_max_reconnects do |timeout, retries|
  end
  
  trap('TERM') {
    stream.stop
    EventMachine.stop if EventMachine.reactor_running? 
  }
end
