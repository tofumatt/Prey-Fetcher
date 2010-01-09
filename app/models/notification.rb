class Notification < ActiveRecord::Base
  belongs_to :user, :foreign_key => :twitter_user_id
	
	def self.this_month
	  count(:conditions => { :created_at => Date.today - 30..Date.tomorrow })
	end
	
	# Return the total number of notifications sent
	def self.count_all_from_cache
	  @count = Rails.cache.fetch('Notification_count') { { :value => count, :expiry => (Time.now.to_i + 300) } }
	  Rails.cache.delete('Notification_count') if @count[:expiry] < Time.now.to_i
	  
	  @count[:value]
	end
end
