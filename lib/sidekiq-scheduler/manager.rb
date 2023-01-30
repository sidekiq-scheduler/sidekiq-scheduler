require 'sidekiq-scheduler/schedule'
require 'sidekiq-scheduler/scheduler'

module SidekiqScheduler

  # The delayed job router in the system.  This
  # manages the scheduled jobs pushed messages
  # from Redis onto the work queues
  #
  class Manager
    def initialize(config)
      set_current_scheduler_options(config)

      @scheduler_instance = SidekiqScheduler::Scheduler.new(config)
      SidekiqScheduler::Scheduler.instance = @scheduler_instance
      Sidekiq.schedule = config.schedule if @scheduler_instance.enabled
    end

    def stop
      @scheduler_instance.clear_schedule!
    end

    def start
      @scheduler_instance.load_schedule!
    end

    private

    def set_current_scheduler_options(config)
      enabled = SidekiqScheduler::Scheduler.enabled
      dynamic = SidekiqScheduler::Scheduler.dynamic
      dynamic_every = SidekiqScheduler::Scheduler.dynamic_every
      listened_queues_only = SidekiqScheduler::Scheduler.listened_queues_only

      config.enabled = enabled unless enabled.nil?
      config.dynamic = dynamic unless dynamic.nil?
      config.dynamic_every = dynamic_every unless dynamic_every.nil?
      unless Sidekiq.schedule.nil? || (Sidekiq.schedule.respond_to?(:empty?) && Sidekiq.schedule.empty?)
        config.schedule = Sidekiq.schedule
      end
      config.listened_queues_only = listened_queues_only unless listened_queues_only.nil?
    end
  end
end
