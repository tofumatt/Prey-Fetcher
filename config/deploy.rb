gem 'ktheory-vlad-git'

set :application, 'preyfetcher'
set :user, 'preyfetcher'
set :domain, "#{user}@shiva.hosts.kicksass.ca" # where to ssh
set :deploy_to, '/home/preyfetcher/sites/preyfetcher.com/' # target directory on server
set :repository, 'git@github.com:tofumatt/Prey-Fetcher.git' # git repo to clone
set :revision, 'origin/master' # git branch to deploy
set :config_files, ['database.yml', 'prey_fetcher.rb']
set :stream_controller, "#{current_path}/lib/stream_controller.rb"

set :asset_servers, [
  {
    :user => 'preyfetcher',
    :server => "ifrit.hosts.kicksass.ca",
    :path => "/home/preyfetcher/sites/static.preyfetcher.com"
  }
]

namespace :vlad do
  desc "Symlinks the configuration files"
  remote_task :symlink_config, :roles => :web do
    config_files.each do |file|
      run "ln -s #{shared_path}/config/#{file} #{current_path}/config/#{file}"
    end
  end
  
  desc "Login to the git server via ssh for the first time"
  remote_task :do_ssh do 
    run "cd #{deploy_to} && ssh #{repository}" 
  end
  
  desc "Copy non-versioned config files to server"
  remote_task :config_create do
    run "umask 02 && mkdir -p #{shared_path}/config"
  end
  task :config_create do
    config_files.each do |file|
      system "scp #{Dir.pwd}/config/#{file} #{domain}:#{shared_path}/config/#{file}"
    end
  end
  
  desc "Update the crontab from whenever"
  remote_task :update_crontab do
    run "cd #{current_path} && whenever --update-crontab #{application}"
  end
  
  desc "Start the streaming daemon"
  remote_task :stream_start do
    run "#{stream_controller} start"
  end
  
  desc "Stop the streaming daemon"
  remote_task :stream_stop do
    run "#{stream_controller} stop"
  end
  
  desc "Restart the streaming daemon"
  remote_task :stream_restart do
    run "#{stream_controller} restart"
  end
  
  desc "Full deployment cycle: Update, migrate, restart, cleanup"
  remote_task :deploy, :roles => :app do
    Rake::Task['vlad:stream_stop'].invoke
    Rake::Task['vlad:update'].invoke
    Rake::Task['vlad:symlink_config'].invoke
    Rake::Task['vlad:migrate'].invoke
    Rake::Task['vlad:stream_start'].invoke
    Rake::Task['vlad:start_app'].invoke
    Rake::Task['vlad:cleanup'].invoke
  end
end
