require 'rufus/scheduler'
require 'thwait'
require 'sidekiq/util'
require 'sidekiq-scheduler/manager'

module Sidekiq
  class Scheduler
    extend Sidekiq::Util

    class << self
      # If set, will try to update the schulde in the loop
      attr_accessor :dynamic
    end

    # the Rufus::Scheduler jobs that are scheduled
    def self.scheduled_jobs
      @@scheduled_jobs
    end

    def self.print_schedule
      if self.rufus_scheduler
        logger.info "Scheduling Info\tLast Run"
        scheduler_jobs = self.rufus_scheduler.all_jobs
        scheduler_jobs.each do |k, v|
          logger.info "#{v.t}\t#{v.last}\t"
        end
      end
    end

    # Pulls the schedule from Sidekiq.schedule and loads it into the
    # rufus scheduler instance
    def self.load_schedule!
      logger.info 'Loading Schedule'

      # Need to load the schedule from redis for the first time if dynamic
      Sidekiq.reload_schedule! if dynamic

      logger.info 'Schedule empty! Set Sidekiq.schedule' if Sidekiq.schedule.empty?

      @@scheduled_jobs = {}

      Sidekiq.schedule.each do |name, config|
        self.load_schedule_job(name, config)
      end

      Sidekiq.redis { |r| r.del(:schedules_changed) }

      logger.info 'Schedules Loaded'
    end

    # modify interval type value to value with options if options available
    def self.optionizate_interval_value(value)
      args = value
      if args.is_a?(::Array)
        return args.first if args.size > 2 || !args.last.is_a?(::Hash)
        # symbolize keys of hash for options
        args[1] = args[1].inject({}) do |m, i|
          key, value = i
          m[(key.to_sym rescue key) || key] = value
          m
        end
      end
      args
    end

    # Loads a job schedule into the Rufus::Scheduler and stores it in @@scheduled_jobs
    def self.load_schedule_job(name, config)
      # If rails_env is set in the config, enforce ENV['RAILS_ENV'] as
      # required for the jobs to be scheduled.  If rails_env is missing, the
      # job should be scheduled regardless of what ENV['RAILS_ENV'] is set
      # to.
      if config['rails_env'].nil? || self.rails_env_matches?(config)
        logger.info "Scheduling #{name} "
        interval_defined = false
        interval_types = %w{cron every}
        interval_types.each do |interval_type|
          if !config[interval_type].nil? && config[interval_type].length > 0
            args = self.optionizate_interval_value(config[interval_type])

            @@scheduled_jobs[name] = self.rufus_scheduler.send(interval_type, *args) do
              logger.info "queueing #{config['class']} (#{name})"
              config.delete(interval_type)
              self.handle_errors { self.enqueue_from_config(config) }
            end

            interval_defined = true

            break
          end
        end

        unless interval_defined
          logger.info "no #{interval_types.join(' / ')} found for #{config['class']} (#{name}) - skipping"
        end
      end
    end

    # Returns true if the given schedule config hash matches the current
    # ENV['RAILS_ENV']
    def self.rails_env_matches?(config)
      config['rails_env'] && ENV['RAILS_ENV'] && config['rails_env'].gsub(/\s/,'').split(',').include?(ENV['RAILS_ENV'])
    end

    def self.handle_errors
      begin
        yield
      rescue Exception => e
        logger.info "#{e.class.name}: #{e.message}"
      end
    end

    # Enqueue a job based on a config hash
    def self.enqueue_from_config(job_config)
      config = job_config.dup

      config['class'] = if config['class'].is_a?(String)
                          config['class'].constantize
                        else
                          config['class']
                        end
      config['args'] = Array(config['args'])

       Sidekiq::Client.push(config)
    end

    def self.rufus_scheduler
      @rufus_scheduler ||= Rufus::Scheduler.start_new
    end

    # Stops old rufus scheduler and creates a new one.  Returns the new
    # rufus scheduler
    def self.clear_schedule!
      self.rufus_scheduler.stop
      @rufus_scheduler = nil
      @@scheduled_jobs = {}
      self.rufus_scheduler
    end

    def self.reload_schedule!
      logger.info 'Reloading Schedule'
      self.clear_schedule!
      self.load_schedule!
    end

    def self.update_schedule
      if Sidekiq.redis { |r| r.scard(:schedules_changed) } > 0
        logger.info 'Updating schedule'
        Sidekiq.reload_schedule!
        while schedule_name = Sidekiq.redis { |r| r.spop(:schedules_changed) }
          if Sidekiq.schedule.keys.include?(schedule_name)
            self.unschedule_job(schedule_name)
            self.load_schedule_job(schedule_name, Sidekiq.schedule[schedule_name])
          else
            self.unschedule_job(schedule_name)
          end
        end
        logger.info 'Schedules Loaded'
      end
    end

    def self.unschedule_job(name)
      if self.scheduled_jobs[name]
        logger.debug "Removing schedule #{name}"
        self.scheduled_jobs[name].unschedule
        self.scheduled_jobs.delete(name)
      end
    end

  end
end