if Gem::Version.new(Sidekiq::VERSION) >= Gem::Version.new('7.0.0')
  require 'sidekiq/capsule'
end

def reset_sidekiq_config!
  cfg = Sidekiq::Config.new
  cfg.logger = ::Logger.new("/dev/null")
  cfg.logger.level = Logger::WARN
  Sidekiq.instance_variable_set :@config, cfg
  cfg
end