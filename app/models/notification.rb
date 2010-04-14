class Notification < ActiveRecord::Base
  belongs_to :user, :foreign_key => :twitter_user_id
	
	def self.this_month
	  count(:conditions => { :created_at => Date.today - 30..Date.tomorrow })
	end
end
