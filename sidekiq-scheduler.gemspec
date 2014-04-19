$:.push File.expand_path('../lib', __FILE__)

# Maintain your gem's version:
require 'sidekiq-scheduler/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|

  s.name        = 'sidekiq-scheduler'
  s.version     = SidekiqScheduler::VERSION
  s.authors     = ['Morton Jonuschat', 'Adrian Gomez']
  s.email       = ['adrian_g171@hotmail.com']
  s.license     = 'MIT'
  s.homepage    = 'https://github.com/moove-it/sidekiq-scheduler'
  s.summary     = 'Light weight job scheduling extension for Sidekiq'
  s.description = 'Light weight job scheduling extension for Sidekiq that adds support for queueing items in the future.'

  s.executables = ['sidekiq-scheduler']
  s.files       = Dir['{app,bin,config,db,lib}/**/*'] + %w[MIT-LICENSE Rakefile README.md]
  s.test_files  = Dir['test/**/*']

  s.add_dependency 'sidekiq',         '~> 2', '>= 2.12'
  s.add_dependency 'redis',           '~> 3'
  s.add_dependency 'rufus-scheduler', '~> 2'
  s.add_dependency 'multi_json',      '~> 1'

  s.add_development_dependency 'rake',        '~> 10.0'
  s.add_development_dependency 'timecop',     '~> 0'
  s.add_development_dependency 'mocha',       '~> 0'
  s.add_development_dependency 'minitest',    '~> 5.0'
  s.add_development_dependency 'mock_redis',  '~> 0'
  s.add_development_dependency 'simplecov',   '~> 0'

end