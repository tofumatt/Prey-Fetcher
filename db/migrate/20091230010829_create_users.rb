class CreateUsers < ActiveRecord::Migration
  def self.up
    create_table :users do |t|
      t.integer :twitter_user_id, :limit => 8
      t.string :twitter_username
      t.string :prowl_api_key
      t.string :access_key
      t.string :access_secret
      t.integer :mention_since_id, :limit => 8, :default => 1
      t.integer :dm_since_id, :limit => 8, :default => 1
      t.integer :retweet_since_id, :limit => 8, :default => 1
      t.boolean :enable_mentions, :default => true
      t.boolean :enable_dms, :default => true
      t.boolean :enable_retweets, :default => false
      t.integer :mention_priority, :default => 0
      t.integer :dm_priority, :default => 0
      t.integer :retweet_priority, :default => 0

      t.timestamps
    end
  end

  def self.down
    drop_table :users
  end
end
