#!/usr/bin/env ruby

require "rubygems"
require "daemons"
require "bundler"
require "yaml"
Bundler.setup(:default, ((ENV['RACK_ENV']) ? ENV['RACK_ENV'].to_sym : :development))

Bundler.require

Daemons.run(File.join(File.dirname(__FILE__), 'streaming.rb'))
