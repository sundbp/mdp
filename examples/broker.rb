require 'rubygems'
require 'bundler/setup'

require 'mdp'
broker = MDP::Broker.new
broker.run
