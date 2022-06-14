require 'sidekiq'
require 'tilt/erb'

require_relative 'sidekiq/scheduler'
require_relative 'sidekiq-scheduler/version'
require_relative 'sidekiq-scheduler/manager'
require_relative 'sidekiq-scheduler/redis_manager'
require_relative 'sidekiq-scheduler/extensions/schedule'

SIDEKIQ_GTE_6_5_0 = Gem::Version.new(Sidekiq::VERSION) >= Gem::Version.new('6.5.0')

Sidekiq.configure_server do |config|

  config.on(:startup) do
    # schedules_changed's type was changed from SET to ZSET, so we remove old versions at startup
    SidekiqScheduler::RedisManager.clean_schedules_changed

    # Accessing the raw @config hash through .options is deprecated in 6.5 and to be removed in 7.0
    config_options = SIDEKIQ_GTE_6_5_0 ? Sidekiq.instance_variable_get(:@config) : config.options

    schedule_manager = SidekiqScheduler::Manager.new(config_options)
    if SIDEKIQ_GTE_6_5_0
      config[:schedule_manager] = schedule_manager
      config[:schedule_manager].start
    else
      config.options[:schedule_manager] = schedule_manager
      config.options[:schedule_manager].start
    end
  end

  config.on(:quiet) do
    if SIDEKIQ_GTE_6_5_0
      config[:schedule_manager].stop
    else
      config.options[:schedule_manager].stop
    end
  end

end
