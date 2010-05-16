class RemoveRetweetsFromUsers < ActiveRecord::Migration
  def self.up
    remove_column :users, :retweet_since_id
    remove_column :users, :enable_retweets
    remove_column :users, :retweet_priority
  end

  def self.down
    add_column :users, :retweet_since_id, :integer, :limit => 8, :default => 1
    add_column :users, :enable_retweets, :boolean, :default => false
    add_column :users, :retweet_priority, :integer, :default => 0
  end
end
