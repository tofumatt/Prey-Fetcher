#!/usr/bin/env ruby

require 'rubygems'
require 'daemons'
require 'bundler'
Bundler.setup

Bundler.require

Daemons.run(File.join(File.dirname(__FILE__), 'streaming.rb'))
