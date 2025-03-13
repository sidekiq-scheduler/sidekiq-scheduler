if Gem::Version.new(Sidekiq::VERSION) >= Gem::Version.new('7.0.0')
  require 'sidekiq/capsule'
end

def reset_sidekiq_config!(options={})
  cfg = Sidekiq::Config.new(options)
  cfg.logger = ::Logger.new("/dev/null")
  cfg.logger.level = Logger::WARN
  Sidekiq.instance_variable_set :@config, cfg
  cfg
end

def sidekiq_config_for_options(options = {})
  Sidekiq::Config.new(options)
end

class SConfigWrapper
  def reset!(options={})
    @sconfig = reset_sidekiq_config!(options)
    @sconfig.queues = []
    @sconfig
  end

  def queues=(val)
    @sconfig.queues = val
  end
end
