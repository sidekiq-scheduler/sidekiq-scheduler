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

class SConfigWrapper
  def reset!
    if SIDEKIQ_GTE_7_0_0
      @sconfig = reset_sidekiq_config!
      @sconfig.queues = []
    else
      # Sidekiq 6 the default queues was an empty array https://github.com/mperham/sidekiq/blob/6-x/lib/sidekiq.rb#L21
      Sidekiq.options[:queues] = Sidekiq::DEFAULTS[:queues]
    end
  end

  def queues=(val)
    if SIDEKIQ_GTE_7_0_0
      @sconfig.queues = val
    else
      Sidekiq.options[:queues] = val
    end
  end
end