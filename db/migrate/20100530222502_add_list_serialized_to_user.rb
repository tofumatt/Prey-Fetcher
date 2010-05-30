class AddListSerializedToUser < ActiveRecord::Migration
  def self.up
    add_column :users, :lists_serialized, :text
  end

  def self.down
    remove_column :users, :lists_serialized
  end
end
