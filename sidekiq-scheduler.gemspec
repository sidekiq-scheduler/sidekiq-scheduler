$:.push File.expand_path('../lib', __FILE__)

require 'sidekiq-scheduler/version'

Gem::Specification.new do |s|
  s.name        = 'sidekiq-scheduler'
  s.version     = SidekiqScheduler::VERSION
  s.authors     = ['Morton Jonuschat', 'Moove-it']
  s.email       = ['sidekiq-scheduler@moove-it.com']
  s.license     = 'MIT'
  s.homepage    = 'https://moove-it.github.io/sidekiq-scheduler/'
  s.summary     = 'Light weight job scheduling extension for Sidekiq'
  s.description = 'Light weight job scheduling extension for Sidekiq that adds support for queueing jobs in a recurring way.'

  s.files       = Dir['{lib,web}/**/*'] + %w[MIT-LICENSE Rakefile README.md]

  s.add_dependency 'sidekiq',         '>= 3'
  s.add_dependency 'redis',           '~> 4.2'
  s.add_dependency 'rufus-scheduler', '~> 3.2'
  s.add_dependency 'tilt',            '>= 1.4.0'
  s.add_dependency 'thwait'
  s.add_dependency 'e2mmap'

  s.add_development_dependency 'rake',                    '~> 10.0'
  s.add_development_dependency 'timecop',                 '~> 0'
  s.add_development_dependency 'mocha',                   '~> 0'
  s.add_development_dependency 'rspec'
  s.add_development_dependency 'mock_redis',              '~> 0.27.0'
  s.add_development_dependency 'simplecov',               '~> 0'
  s.add_development_dependency 'byebug'

  s.add_development_dependency 'activejob'

  s.add_development_dependency 'coveralls'
  s.add_development_dependency 'rack-test'
  s.add_development_dependency 'sinatra'
end
