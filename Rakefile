# Load up Prey Fetcher
require File.join(File.dirname(__FILE__), "prey_fetcher.rb")

# Set this to true to disable account-linking based on API keys
# when running the prey_fetcher:setup_accounts task.
DONT_LINK_ACCOUNTS_WITH_THE_SAME_PROWL_API_KEYS = false

asset_servers = [
  {
    :user => 'preyfetcher',
    :server => "ifrit.hosts.kicksass.ca",
    :path => "/home/preyfetcher/sites/static.preyfetcher.com"
  }
]

task :default => :test

namespace :deploy do
  desc "Copy public files to asset webserver"
  task :update_assets do
    Rake::Task['deploy:build_sass'].invoke
    asset_servers.each do |server|
      system "scp -r #{Dir.pwd}/public/* #{server[:user]}@#{server[:server]}:#{server[:path]}"
    end
    Rake::Task['deploy:clear_sass'].invoke
  end
  
  desc 'Updates stylesheets if necessary from their Sass templates.'
  task :build_sass do
    Dir['views/*.sass'].each do |file|
      system "sass #{file} #{file.gsub(/^views\/(.*)\.sass$/, "public/stylesheets/\\1.css")}"
    end
  end
  
  desc 'Delete Sass stylesheets.'
  task :clear_sass do
    sass_files = []
    Dir['views/*.sass'].each do |file|
      sass_files << file.gsub(/^views\/(.*)\.sass$/, "public/stylesheets/\\1.css")
    end
    
    sass_files.each do |file|
      system "rm #{file}"
    end
  end
end

namespace :prey_fetcher do
  # Called by cron, etc. to check all user accounts for new
  # tweets/direct messages, then send all notifications to Prowl.
  desc "Check Twitter for all Prey Fetcher users"
  task :check_twitter do
    # Loop through all users and send any notifications.
    User.all.each do |u|
      # If the user doesn't have an API key we won't do anything
      unless u.nil? || u.prowl_api_key.nil? || u.prowl_api_key.blank?
        u.check_dms if u.enable_dms
        u.check_lists if u.enable_list
      end
    end
  end
  
  # Setup all Account records.
  desc "Setup Account records; one-time operation."
  task :setup_accounts do
    User.all.each do |u|
      if u.account_id.nil? && User.first(:id => u.id).account_id.nil? # Do another lookup, because the
                                                                      # user in-memory won't have an
                                                                      # account_id.
        account = Account.create!(
          :name => u.twitter_username,
          :prowl_api_key => u.prowl_api_key,
          :custom_url => u.custom_url,
          # Because we ignore callbacks
          :created_at => Time.now,
          :updated_at => Time.now
        )
        u.update(:account_id => account.id)
        
        next if DONT_LINK_ACCOUNTS_WITH_THE_SAME_PROWL_API_KEYS || u.prowl_api_key.nil? || u.prowl_api_key.blank?
        
        other_users_with_same_api_key = User.all(:prowl_api_key => u.prowl_api_key)
        
        unless other_users_with_same_api_key.nil?
          other_users_with_same_api_key.each do |other_user|
            other_user.update(:account_id => u.account_id)
          end
        end
      end
    end
  end
  
  # Verify all user accounts.
  desc "Verify credentials for all Prey Fetcher users"
  task :verify_accounts do
    # Loop through all users and check their accounts.
    User.all.each do |u|
      u.verify_credentials
    end
  end
end

desc "Run all Prey Fetcher tests"
task :test do
  system "ruby test/prey_fetcher_test.rb"
end
