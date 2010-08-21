# Load Vlad The Deployer
# begin
#   require 'vlad'
#   Vlad.load :app => :passenger, :scm => :git
# rescue LoadError
#   # So the server doesn't fail if it doesn't have Vlad
#   puts "No Vlad!!! :-("
# end

namespace :prey_fetcher do
  # Called by cron, etc. to check all user accounts for new
  # tweets/direct messages, then send all notifications to Prowl.
  desc "Check Twitter for all Prey Fetcher users"
  task :check_twitter do
    require File.join(File.dirname(__FILE__), "prey_fetcher.rb")
    # Loop through all users and send any notifications.
    User.all.each do |u|
      # If the user doesn't have an API key we won't do anything
      unless u.prowl_api_key.nil? || u.prowl_api_key.blank?
        u.check_dms if u.enable_dms
        u.check_lists if u.enable_list
      end
    end
  end
  
  # Verify all user accounts.
  desc "Verify credentials for all Prey Fetcher users"
  task :verify_accounts do
    require File.join(File.dirname(__FILE__), "prey_fetcher.rb")
    # Loop through all users and check their accounts.
    User.all.each do |u|
      u.verify_credentials
    end
  end
end
