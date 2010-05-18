require File.join(File.dirname(__FILE__), '..', 'lib', 'twitter')
require File.join(File.dirname(__FILE__), 'helpers', 'config_store')
require 'pp'

config = ConfigStore.new("#{ENV['HOME']}/.twitter")

httpauth = Twitter::HTTPAuth.new(config['email'], config['password'])
base = Twitter::Base.new(httpauth)

pp base.lists('pengwynn')
pp base.list_members('pengwynn', 'rubyists')