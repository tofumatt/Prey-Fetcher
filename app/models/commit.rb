class Commit < ActiveRecord::Base
  validates_uniqueness_of :sha
  validates_presence_of :sha, :url, :author_name, :timestamp
end
