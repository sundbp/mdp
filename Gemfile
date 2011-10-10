require 'rbconfig'

source :rubygems

gemspec

gem 'ffi-rzmq', :path => "~/dev/_mine/ffi-rzmq"
#gem 'ffi-rzmq', :git => 'https://github.com/sundbp/ffi-rzmq.git'

group :development, :test do
  gem 'rake',       '~> 0.9.2'
  gem 'ore-tasks',  '~> 0.4'
  gem 'rspec',      '~> 2.4'
  gem 'kramdown'
  gem 'yard',       '~> 0.7'
  gem 'rcov',       '~> 0.9.10'
end

group :development do
  gem 'fuubar',       '~> 0.0.6'
  gem 'guard',        '~> 0.3.0'
  gem 'guard-rspec',  '~> 0.2.0'
  
  if RbConfig::CONFIG['host_os'] == 'windows'
    gem 'rb-notifu'
    gem 'rb-fchange'
  end
  
  if RbConfig::CONFIG['host_os'] == 'darwin'
    gem 'rb-fsevent'
    gem 'growl'
  end
end

group :test do
  gem 'rspec_junit_formatter', :git => 'https://github.com/sj26/rspec_junit_formatter.git'
end
