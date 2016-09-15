require 'redis'

require 'sidekiq/util'

require 'sidekiq/scheduler'
require 'sidekiq-scheduler/schedule'

module SidekiqScheduler

  # The delayed job router in the system.  This
  # manages the scheduled jobs pushed messages
  # from Redis onto the work queues
  #
  class Manager
    include Sidekiq::Util

    def initialize(options)
      Sidekiq::Scheduler.enabled = options[:enabled]
      Sidekiq::Scheduler.dynamic = options[:dynamic]
      Sidekiq::Scheduler.listened_queues_only = options[:listened_queues_only]
      Sidekiq.schedule = options[:schedule] || {}
    end

    def stop
      Sidekiq::Scheduler.clear_schedule!
    end

    def start
      Sidekiq::Scheduler.load_schedule!
    end

    def reset
      clear_scheduled_work
    end

  end

end
