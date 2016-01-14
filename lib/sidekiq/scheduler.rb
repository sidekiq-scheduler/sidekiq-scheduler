require 'rufus/scheduler'
require 'thwait'
require 'sidekiq/util'
require 'sidekiq-scheduler/manager'

module Sidekiq
  class Scheduler
    extend Sidekiq::Util

    # We expect rufus jobs to have #params
    Rufus::Scheduler::Job.module_eval do

      alias_method :params, :opts

    end

    class << self

      # Set to enable or disable the scheduler.
      attr_accessor :enabled

      # Set to update the schedule in runtime in a given time period.
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
        scheduler_jobs.each do |_, v|
          logger.info "#{v.t}\t#{v.last}\t"
        end
      end
    end

    # Pulls the schedule from Sidekiq.schedule and loads it into the
    # rufus scheduler instance
    def self.load_schedule!
      if enabled
        logger.info 'Loading Schedule'

        # Load schedule from redis for the first time if dynamic
        if dynamic
          Sidekiq.reload_schedule!
          self.rufus_scheduler.every('5s') do
            self.update_schedule
          end
        end

        logger.info 'Schedule empty! Set Sidekiq.schedule' if Sidekiq.schedule.empty?

        @@scheduled_jobs = {}

        Sidekiq.schedule.each do |name, config|
          self.load_schedule_job(name, config)
        end

        Sidekiq.redis { |r| r.del(:schedules_changed) }

        logger.info 'Schedules Loaded'
      else
        logger.info 'SidekiqScheduler is disabled'
      end
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
        interval_types = %w{cron every at in}
        interval_types.each do |interval_type|
          if !config[interval_type].nil? && config[interval_type].length > 0
            args = self.optionizate_interval_value(config[interval_type])

            # We want rufus_scheduler to return a job object, not a job id
            opts = { :job => true }

            @@scheduled_jobs[name] = self.rufus_scheduler.send(interval_type, *args, opts) do
              logger.info "queueing #{config['class']} (#{name})"
              config.delete(interval_type)
              self.handle_errors { self.enqueue_job(config) }
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
      config['rails_env'] && ENV['RAILS_ENV'] && config['rails_env'].gsub(/\s/, '').split(',').include?(ENV['RAILS_ENV'])
    end

    def self.handle_errors
      begin
        yield
      rescue StandardError => e
        logger.info "#{e.class.name}: #{e.message}"
      end
    end

    # Enqueue a job based on a config hash
    def self.enqueue_job(job_config)
      config = job_config.dup

      config['class'] = config['class'].constantize if config['class'].is_a?(String)
      config['args'] = Array(config['args'])

      if defined?(ActiveJob::Enqueuing) && config['class'].included_modules.include?(ActiveJob::Enqueuing)
        config['class'].new.enqueue(config)
      else
        Sidekiq::Client.push(config)
      end
    end

    def self.rufus_scheduler_options
      @rufus_scheduler_options ||= {}
    end

    def self.rufus_scheduler_options=(options)
      @rufus_scheduler_options = options
    end

    def self.rufus_scheduler
      @rufus_scheduler ||= Rufus::Scheduler.new rufus_scheduler_options
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
      if enabled
        logger.info 'Reloading Schedule'
        self.clear_schedule!
        self.load_schedule!
      else
        logger.info 'SidekiqScheduler is disabled'
      end
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
