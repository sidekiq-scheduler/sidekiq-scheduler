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
  if SidekiqScheduler::SidekiqAdapter::SIDEKIQ_GTE_7_0_0
    Sidekiq::Config.new(options)
  else
    Sidekiq.options = Sidekiq::DEFAULTS.dup.merge(options)
    Sidekiq
  end
end

class SConfigWrapper
  def reset!(options={})
    if SidekiqScheduler::SidekiqAdapter::SIDEKIQ_GTE_7_0_0
      @sconfig = reset_sidekiq_config!(options)
      @sconfig.queues = []
      @sconfig
    else
      # Sidekiq 6 -> reset the sidekiq config for each test
      Sidekiq.options = Sidekiq::DEFAULTS.dup.merge(options)
      Sidekiq
    end
  end

  def queues=(val)
    if SidekiqScheduler::SidekiqAdapter::SIDEKIQ_GTE_7_0_0
      @sconfig.queues = val
    else
      Sidekiq.options[:queues] = val
    end
  end
end
