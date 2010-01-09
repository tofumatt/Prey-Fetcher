class CreateNotifications < ActiveRecord::Migration
  def self.up
    create_table :notifications do |t|
      t.integer :twitter_user_id, :limit => 8

      t.timestamps
    end
  end

  def self.down
    drop_table :notifications
  end
end
