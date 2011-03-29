# Load up Prey Fetcher
require File.join(File.dirname(__FILE__), "prey_fetcher.rb")

app_servers = [
  {
    :user => 'preyfetcher',
    :server => "stray.hosts.kicksass.ca",
    :path => "/home/preyfetcher/sites/preyfetcher.com",
    :url => 'http://preyfetcher.com/',
    :ruby => '/opt/ruby-enterprise-1.8.7-2010.02/bin/ruby'
  }
]

asset_servers = [
  {
    :user => 'preyfetcher',
    :server => "ifrit.hosts.kicksass.ca",
    :path => "/home/preyfetcher/sites/static.preyfetcher.com"
  }
]

task :default => :test

namespace :deploy do
  desc "Deploy master branch into production"
  task :app do
    Rake::Task['deploy:assets'].invoke
    app_servers.each do |server|
      system "ssh #{server[:user]}@#{server[:server]} 'cd #{server[:path]} && git pull origin master && touch tmp/restart.txt && RACK_ENV=production #{server[:ruby]} #{server[:path]}/stream_controller.rb stop && RACK_ENV=production #{server[:ruby]} #{server[:path]}/stream_controller.rb start && ab -n 10 #{server[:url]}/'"
    end
  end
  
  desc "Copy public files to asset webserver"
  task :assets do
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
        u.check_lists if u.enable_list
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
