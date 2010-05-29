class CreateCommits < ActiveRecord::Migration
  def self.up
    create_table :commits do |t|
      t.string :sha
      t.string :url
      t.string :author_name
      t.string :author_email
      t.text :message
      t.timestamp :timestamp

      t.timestamps
    end
  end

  def self.down
    drop_table :commits
  end
end
