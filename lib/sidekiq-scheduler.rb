require 'sidekiq'
require 'tilt/erb'

require_relative 'sidekiq/scheduler'
require_relative 'sidekiq-scheduler/version'
require_relative 'sidekiq-scheduler/manager'
require_relative 'sidekiq-scheduler/redis_manager'
require_relative 'sidekiq-scheduler/extensions/schedule'

Sidekiq.configure_server do |config|

  config.on(:startup) do
    # schedules_changed's type was changed from SET to ZSET, so we remove old versions at startup
    SidekiqScheduler::RedisManager.clean_schedules_changed

    schedule_manager = SidekiqScheduler::Manager.new(config.options)
    config.options[:schedule_manager] = schedule_manager
    config.options[:schedule_manager].start
  end

  config.on(:shutdown) do
    config.options[:schedule_manager].stop
  end

end
