require 'rufus/scheduler'
require 'thwait'
require 'sidekiq/util'
require 'sidekiq-scheduler/manager'

module Sidekiq
  class Scheduler
    extend Sidekiq::Util

    REGISTERED_JOBS_THRESHOLD_IN_SECONDS = 24 * 60 * 60

    # We expect rufus jobs to have #params
    Rufus::Scheduler::Job.module_eval do

      alias_method :params, :opts

    end

    class << self

      # Set to enable or disable the scheduler.
      attr_accessor :enabled

      # Set to update the schedule in runtime in a given time period.
      attr_accessor :dynamic

      # Set to schedule jobs only when will be pushed to queues listened by sidekiq
      attr_accessor :listened_queues_only
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
          if !listened_queues_only || enabled_queue?(config['queue'])
            self.load_schedule_job(name, config)
          else
            logger.info { "Ignoring #{name}, job's queue is not enabled." }
          end
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
        logger.info "Scheduling #{name} #{config}"
        interval_defined = false
        interval_types = %w{cron every at in interval}
        interval_types.each do |interval_type|
          config_interval_type = config[interval_type]

          if !config_interval_type.nil? && config_interval_type.length > 0

            args = self.optionizate_interval_value(config_interval_type)

            # We want rufus_scheduler to return a job object, not a job id
            opts = { :job => true }

            @@scheduled_jobs[name] = self.rufus_scheduler.send(interval_type, *args, opts) do |job, time|
              config.delete(interval_type)

              idempotent_job_enqueue(name, time, config)
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

    # Pushes the job into Sidekiq if not already pushed for the given time
    #
    # @param [String] job_name The job's name
    # @param [Time] time The time when the job got cleared for triggering
    # @param [Hash] config Job's config hash
    def self.idempotent_job_enqueue(job_name, time, config)
      registered = register_job_instance(job_name, time)

      if registered
        logger.info "queueing #{config['class']} (#{job_name})"

        self.handle_errors { self.enqueue_job(config) }

        remove_elder_job_instances(job_name)
      else
        logger.debug { "Ignoring #{job_name} job as it has been already enqueued" }
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
      config = prepare_arguments(job_config.dup)

      if active_job_enqueue?(config['class'])
        enque_with_active_job(config)
      else
        enque_with_sidekiq(config)
      end
    end

    def self.rufus_scheduler_options
      @rufus_scheduler_options ||= {}
    end

    def self.rufus_scheduler_options=(options)
      @rufus_scheduler_options = options
    end

    def self.rufus_scheduler
      @rufus_scheduler ||= Rufus::Scheduler.new(rufus_scheduler_options)
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

    def self.enque_with_active_job(config)
      initialize_active_job(config['class'], config['args']).enqueue(config)
    end

    def self.enque_with_sidekiq(config)
      Sidekiq::Client.push(config)
    end

    def self.initialize_active_job(klass, args)
      if args.is_a?(Array)
        klass.new(*args)
      else
        klass.new(args)
      end
    end

    # Returns true if the enqueuing needs to be done for an ActiveJob
    #  class false otherwise.
    #
    # @param [Class] klass the class to check is decendant from ActiveJob
    #
    # @return [Boolean]
    def self.active_job_enqueue?(klass)
      defined?(ActiveJob::Enqueuing) && klass.included_modules.include?(ActiveJob::Enqueuing)
    end

    # Convert the given arguments in the format expected to be enqueued.
    #
    # @param [Hash] config the options to be converted
    # @option config [String] class the job class
    # @option config [Hash/Array] args the arguments to be passed to the job
    #   class
    #
    # @return [Hash]
    def self.prepare_arguments(config)
      config['class'] = config['class'].constantize if config['class'].is_a?(String)

      if config['args'].is_a?(Hash)
        config['args'].symbolize_keys! if config['args'].respond_to?(:symbolize_keys!)
      else
        config['args'] = Array(config['args'])
      end

      config
    end

    # Returns true if a job's queue is being listened on by sidekiq
    #
    # @param [String] job_queue Job's queue name
    #
    # @return [Boolean]
    def self.enabled_queue?(job_queue)
      queues = Sidekiq.options[:queues]

      queues.empty? || queues.include?(job_queue)
    end

    # Registers a queued job instance
    #
    # @param [String] job_name The job's name
    # @param [Time] time Time at which the job was cleared by the scheduler
    #
    # @return [Boolean] true if the job was registered, false when otherwise
    def self.register_job_instance(job_name, time)
      pushed_job_key = pushed_job_key(job_name)

      registered, _ = Sidekiq.redis do |r|
        r.pipelined do
          r.zadd(pushed_job_key, time.to_i, time.to_i)
          r.expire(pushed_job_key, REGISTERED_JOBS_THRESHOLD_IN_SECONDS)
        end
      end

      registered
    end

    def self.remove_elder_job_instances(job_name)
      Sidekiq.redis do |r|
        r.zremrangebyscore(pushed_job_key(job_name), 0, Time.now.to_i - REGISTERED_JOBS_THRESHOLD_IN_SECONDS)
      end
    end

    # Returns the key of the Redis sorted set used to store job enqueues
    #
    # @param [String] job_name The name of the job
    #
    # @return [String]
    def self.pushed_job_key(job_name)
      "sidekiq-scheduler:pushed:#{job_name}"
    end
  end
end
