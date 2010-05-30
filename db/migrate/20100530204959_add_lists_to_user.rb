class AddListsToUser < ActiveRecord::Migration
  def self.up
    add_column :users, :list_since_id, :integer, :limit => 8, :default => 1
    add_column :users, :notification_list, :integer
    add_column :users, :enable_list, :boolean, :default => false
    add_column :users, :list_priority, :integer, :default => 0
    add_column :users, :list_owner, :string
  end

  def self.down
    remove_column :users, :notification_list
    remove_column :users, :list_since_id
    remove_column :users, :list_priority
    remove_column :users, :enable_list
    remove_column :users, :list_owner
  end
end
