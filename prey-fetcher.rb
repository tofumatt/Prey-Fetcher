# Development mode
require "rubygems"
require "bundler"
Bundler.setup

# Production mode (locked)
# require ".bundle/environment"

Bundler.require

# Set Sinatra's variables
set :app_file, __FILE__
set :root, File.dirname(__FILE__)
set :public, "public"
set :views, "views"

class Commit
  include DataMapper::Resource
  
  property :id, Serial
  property :sha, String, :required => true, :unique => true
  property :url, String, :required => true
  property :author_name, String, :required => true
  property :author_email, String, :required => true
  property :message, Text
  property :timestamp, DateTime, :required => true
  # Timestamps
  property :created_at, DateTime
  property :updated_at, DateTime
end

class Notification
  include DataMapper::Resource
  
  property :id, Serial
  property :twitter_user_id, Integer
  # Timestamps
  property :created_at, DateTime
  property :updated_at, DateTime
  
  belongs_to :user, :foreign_key => :twitter_user_id
  
  def self.this_month
	  count(:conditions => { :created_at => Date.today - 30..Date.tomorrow })
	end
end

class User
  include DataMapper::Resource
  include DataMapper::Validate
  
  property :id, Serial
  property :twitter_user_id, Integer
  property :twitter_username, String
  property :prowl_api_key, String
  property :access_key, String
  property :access_secret, String
  # Mentions/replies
  property :enable_mentions, Boolean, :default => true
  property :mention_priority, Integer, :default => 0
  # Direct Messages
  property :enable_dms, Boolean, :default => true
  property :dm_since_id, Integer, :default => 1
  property :dm_priority, Integer, :default => 0
  # Lists
  property :enable_list, Boolean, :default => true
  property :notification_list, Integer
  property :list_priority, Integer, :default => 0
  property :list_since_id, Integer, :default => 1
  property :list_owner, String
  property :lists_serialized, Object
  # Timestamps
  property :created_at, DateTime
  property :updated_at, DateTime
  
  has n, :notifications
  
  validates_with_method :prowl_api_key, :method => :prowl_api_key_is_valid?
  
  # Test a user's Prowl API key via the Prowl API
  def prowl_api_key_is_valid?
    return [false, "You must supply a Prowl API key."] if self.prowl_api_key.nil? || self.prowl_api_key.blank?
    
    require "fastprowl"
    #logger.debug Time.now.to_s
    #logger.debug 'Validating a Prowl API Key...'
    
    if FastProwl.verify(self.prowl_api_key)
      true
    else
      [false, "The Prowl API key you supplied was invalid."]
    end
  end
end

get "/" do
  "Push your tweets to nowhere."
end
