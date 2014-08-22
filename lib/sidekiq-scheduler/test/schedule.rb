require 'multi_json'

require 'sidekiq/scheduler'
require 'sidekiq-scheduler/schedule'

module SidekiqScheduler
  module Schedule

    def set_schedule(name, config)
      existing_config = get_schedule(name)
      if !existing_config || existing_config != config
        Sidekiq::Scheduler.schedules[name] = MultiJson.encode(config)
        Sidekiq::Scheduler.schedules_changed << name
      end
      config
    end

    def remove_schedule(name)
      Sidekiq::Scheduler.schedules.delete(name)
    end

    def get_schedule(name = nil)
      if name
        Sidekiq::Scheduler.schedules[name]
      else
        Sidekiq::Scheduler.schedules
      end
    end

  end
end

module Sidekiq
  class Scheduler

    def self.schedules
      @schedules ||= {}
    end

    def self.schedules_changed
      @schedules_changed ||= []
    end

  end
end