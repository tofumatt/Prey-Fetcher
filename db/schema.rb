# This file is auto-generated from the current state of the database. Instead of editing this file, 
# please use the migrations feature of Active Record to incrementally modify your database, and
# then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your database schema. If you need
# to create the application database on another system, you should be using db:schema:load, not running
# all the migrations from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20100516012233) do

  create_table "notifications", :force => true do |t|
    t.integer  "twitter_user_id", :limit => 8
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "users", :force => true do |t|
    t.integer  "twitter_user_id",  :limit => 8
    t.string   "twitter_username"
    t.string   "prowl_api_key"
    t.string   "access_key"
    t.string   "access_secret"
    t.integer  "mention_since_id", :limit => 8, :default => 1
    t.integer  "dm_since_id",      :limit => 8, :default => 1
    t.boolean  "enable_mentions",               :default => true
    t.boolean  "enable_dms",                    :default => true
    t.integer  "mention_priority",              :default => 0
    t.integer  "dm_priority",                   :default => 0
    t.datetime "created_at"
    t.datetime "updated_at"
  end

end
