# encoding: utf-8

require 'rubygems'

begin
  require 'bundler'
rescue LoadError => e
  warn e.message
  warn "Run `gem install bundler` to install Bundler."
  exit e.status_code
end

begin
  Bundler.setup(:development)
rescue Bundler::BundlerError => e
  warn e.message
  warn "Run `bundle install` to install missing gems."
  exit e.status_code
end

require 'rake'

require 'ore/tasks'
Ore::Tasks.new

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new

task :test => :spec
task :default => :spec

require 'yard'
YARD::Rake::YardocTask.new  
task :doc => :yard

desc "Run specs with rcov"
RSpec::Core::RakeTask.new("spec:rcov") do |t|
  t.rcov = true
  t.rcov_opts = %w{--exclude "spec\/,jsignal_internal"}
  t.rspec_opts = ["--format documentation", "--format RspecJunitFormatter", "--out reports/rspec.xml"]
end
