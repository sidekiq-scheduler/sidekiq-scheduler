require 'redis'

require 'sidekiq/util'

require 'sidekiq-scheduler/schedule'
require 'sidekiq-scheduler/scheduler'

module SidekiqScheduler

  # The delayed job router in the system.  This
  # manages the scheduled jobs pushed messages
  # from Redis onto the work queues
  #
  class Manager
    include Sidekiq::Util

    DEFAULT_SCHEDULER_OPTIONS = {
      enabled: true,
      dynamic: false,
      dynamic_every: '5s',
      schedule: {}
    }

    def initialize(options)
      scheduler_options = load_scheduler_options(options)

      @scheduler_instance = SidekiqScheduler::Scheduler.new(scheduler_options)
      SidekiqScheduler::Scheduler.instance = @scheduler_instance
      Sidekiq.schedule = scheduler_options[:schedule] if @scheduler_instance.enabled
    end

    def stop
      @scheduler_instance.clear_schedule!
    end

    def start
      @scheduler_instance.load_schedule!
    end

    private

    def load_scheduler_options(options)
      options[:listened_queues_only] = options.fetch(:scheduler, {})[:listened_queues_only]
      scheduler_options = DEFAULT_SCHEDULER_OPTIONS.merge(options)

      current_options = {
        enabled: SidekiqScheduler::Scheduler.enabled,
        dynamic: SidekiqScheduler::Scheduler.dynamic,
        dynamic_every: SidekiqScheduler::Scheduler.dynamic_every,
        schedule: Sidekiq.schedule,
        listened_queues_only: SidekiqScheduler::Scheduler.listened_queues_only
      }.delete_if { |_, value| value.nil? }

      scheduler_options.merge(current_options)
    end
  end
end
