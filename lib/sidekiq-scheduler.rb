require 'sidekiq'
require 'tilt/erb'

require_relative 'sidekiq/scheduler'
require_relative 'sidekiq-scheduler/version'
require_relative 'sidekiq-scheduler/manager'
require_relative 'sidekiq-scheduler/redis_manager'
require_relative 'sidekiq-scheduler/config'
require_relative 'sidekiq-scheduler/extensions/schedule'
require_relative 'sidekiq-scheduler/sidekiq_adapter'

Sidekiq.configure_server do |config|

  config.on(:startup) do
    # schedules_changed's type was changed from SET to ZSET, so we remove old versions at startup
    SidekiqScheduler::RedisManager.clean_schedules_changed

    scheduler_config = SidekiqScheduler::Config.new(sidekiq_config: config)

    schedule_manager = SidekiqScheduler::Manager.new(scheduler_config)
    SidekiqScheduler::SidekiqAdapter.start_schedule_manager(sidekiq_config: config, schedule_manager: schedule_manager)
  end

  config.on(:quiet) do
    SidekiqScheduler::SidekiqAdapter.stop_schedule_manager(sidekiq_config: config)
  end

end
