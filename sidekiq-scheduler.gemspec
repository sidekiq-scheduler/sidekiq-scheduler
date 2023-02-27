$:.push File.expand_path('../lib', __FILE__)

require 'sidekiq-scheduler/version'

Gem::Specification.new do |s|
  s.name        = 'sidekiq-scheduler'
  s.version     = SidekiqScheduler::VERSION
  s.authors     = ['Morton Jonuschat', 'Moove-it', 'Marcelo Lauxen']
  s.email       = ['sidekiq-scheduler@moove-it.com', 'marcelolauxen16@gmail.com']
  s.license     = 'MIT'
  s.homepage    = 'https://sidekiq-scheduler.github.io/sidekiq-scheduler/'
  s.summary     = 'Light weight job scheduling extension for Sidekiq'
  s.description = 'Light weight job scheduling extension for Sidekiq that adds support for queueing jobs in a recurring way.'

  s.files       = Dir['{lib,web}/**/*'] + %w[MIT-LICENSE Rakefile README.md CHANGELOG.md]

  s.required_ruby_version = '>= 2.7'

  s.add_dependency 'sidekiq', '>= 6', '< 8'
  s.add_dependency 'rufus-scheduler', '~> 3.2'
  s.add_dependency 'tilt', '>= 1.4.0'

  s.add_development_dependency 'rake', '~> 12.0'
  s.add_development_dependency 'timecop'
  s.add_development_dependency 'mocha'
  s.add_development_dependency 'rspec'
  s.add_development_dependency 'simplecov'
  s.add_development_dependency 'byebug'
  s.add_development_dependency 'activejob'
  s.add_development_dependency 'rack-test'
  s.add_development_dependency 'rack', '< 3'
end
