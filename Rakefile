asset_servers = [
  {
    :user => 'preyfetcher',
    :server => "ifrit.hosts.kicksass.ca",
    :path => "/home/preyfetcher/sites/static.preyfetcher.com"
  }
]

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
    # $log = File.new(File.join(File.dirname(__FILE__), "#{Sinatra::Application.environment}.log"), "a")
    # STDOUT.reopen($log)
    # STDERR.reopen($log)
    
    # Loop through all users and check their accounts.
    User.all.each do |u|
      u.verify_credentials
    end
  end
end
