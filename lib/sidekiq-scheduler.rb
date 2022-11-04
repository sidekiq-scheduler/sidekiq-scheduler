require 'sidekiq'
require 'tilt/erb'

require_relative 'sidekiq/scheduler'
require_relative 'sidekiq-scheduler/version'
require_relative 'sidekiq-scheduler/manager'
require_relative 'sidekiq-scheduler/redis_manager'
require_relative 'sidekiq-scheduler/config'
require_relative 'sidekiq-scheduler/extensions/schedule'

SIDEKIQ_GTE_6_5_0 = Gem::Version.new(Sidekiq::VERSION) >= Gem::Version.new('6.5.0')
SIDEKIQ_GTE_7_0_0 = Gem::Version.new(Sidekiq::VERSION) >= Gem::Version.new('7.0.0')

Sidekiq.configure_server do |config|

  config.on(:startup) do
    # schedules_changed's type was changed from SET to ZSET, so we remove old versions at startup
    SidekiqScheduler::RedisManager.clean_schedules_changed

    scheduler_config = SidekiqScheduler::Config.new(config)

    schedule_manager = SidekiqScheduler::Manager.new(scheduler_config)
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
