gem 'ktheory-vlad-git'

set :user, 'preyfetcher'
set :domain, "#{user}@shiva.hosts.kicksass.ca" # where to ssh
set :deploy_to, '/home/preyfetcher/sites/preyfetcher.com/' # target directory on server
set :repository, 'git@github.com:tofumatt/Prey-Fetcher.git' # git repo to clone
set :revision, 'origin/master' # git branch to deploy
set :config_files, ['database.yml', 'prey_fetcher.rb']
set :stream_controller, "#{current_path}/lib/stream_controller.rb"
set :ree_path, "/opt/ruby-enterprise-1.8.7-2010.01"

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
  
  desc "Load Ruby Enterprise Edition"
  remote_task :load_ree_env do
    run "export PATH=#{ree_path}/bin/:$PATH"
    run "export GEM_HOME=#{ree_path}/lib/ruby/gems/1.8/gems/"
  end
  
  desc "Start the streaming daemon"
  remote_task :start_stream => :load_ree_env do
    run "#{stream_controller} start"
  end
  
  desc "Stop the streaming daemon"
  remote_task :stop_stream => :load_ree_env do
    run "#{stream_controller} stop"
  end
  
  desc "Restart the streaming daemon"
  remote_task :restart_stream => :load_ree_env do
    run "#{stream_controller} restart"
  end
  
  desc "Full deployment cycle: Update, migrate, restart, cleanup"
  remote_task :deploy, :roles => :app do
    Rake::Task['vlad:stop_stream'].invoke
    Rake::Task['vlad:update'].invoke
    Rake::Task['vlad:symlink_config'].invoke
    Rake::Task['vlad:migrate'].invoke
    Rake::Task['vlad:start_stream'].invoke
    Rake::Task['vlad:start_app'].invoke
    Rake::Task['vlad:cleanup'].invoke
  end
end
