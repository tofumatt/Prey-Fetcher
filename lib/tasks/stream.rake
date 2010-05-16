# Control the streaming daemon from rake
namespace :stream do
  desc "Start the streaming daemon"
  task :start do
    system "#{stream_controller} start"
  end
  
  desc "Stop the streaming daemon"
  task :stop do
    system "#{stream_controller} stop"
  end
  
  desc "Restart the streaming daemon"
  task :restart do
    system "#{stream_controller} restart"
  end
end
