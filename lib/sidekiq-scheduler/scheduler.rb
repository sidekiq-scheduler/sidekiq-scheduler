require 'rufus/scheduler'
require 'thwait'
require 'sidekiq/util'
require 'json'
require 'sidekiq-scheduler/manager'
require 'sidekiq-scheduler/rufus_utils'
require 'sidekiq-scheduler/redis_manager'

module SidekiqScheduler
  class Scheduler
    extend Sidekiq::Util

    # We expect rufus jobs to have #params
    Rufus::Scheduler::Job.module_eval do
      alias_method :params, :opts
    end

    # Set to enable or disable the scheduler.
    attr_accessor :enabled

    # Set to update the schedule in runtime in a given time period.
    attr_accessor :dynamic

    # Set to update the schedule in runtime dynamically per this period.
    attr_accessor :dynamic_every

    # Set to schedule jobs only when will be pushed to queues listened by sidekiq
    attr_accessor :listened_queues_only

    class << self

      def instance
        @instance = new unless @instance
        @instance
      end

      def instance=(value)
        @instance = value
      end

      def method_missing(method, *arguments, &block)
        instance_methods.include?(method) ? instance.public_send(method, *arguments) : super
      end
    end

    def initialize(options = {})
      self.enabled = options[:enabled]
      self.dynamic = options[:dynamic]
      self.dynamic_every = options[:dynamic_every]
      self.listened_queues_only = options[:listened_queues_only]
    end

    # the Rufus::Scheduler jobs that are scheduled
    def scheduled_jobs
      @scheduled_jobs
    end

    def print_schedule
      if rufus_scheduler
        Sidekiq.logger.info "Scheduling Info\tLast Run"
        scheduler_jobs = rufus_scheduler.all_jobs
        scheduler_jobs.each_value do |v|
          Sidekiq.logger.info "#{v.t}\t#{v.last}\t"
        end
      end
    end

    # Pulls the schedule from Sidekiq.schedule and loads it into the
    # rufus scheduler instance
    def load_schedule!
      if enabled
        Sidekiq.logger.info 'Loading Schedule'

        # Load schedule from redis for the first time if dynamic
        if dynamic
          Sidekiq.reload_schedule!
          @current_changed_score = Time.now.to_f
          rufus_scheduler.every(dynamic_every) do
            update_schedule
          end
        end

        Sidekiq.logger.info 'Schedule empty! Set Sidekiq.schedule' if Sidekiq.schedule.empty?

        @scheduled_jobs = {}
        queues = sidekiq_queues

        Sidekiq.schedule.each do |name, config|
          if !listened_queues_only || enabled_queue?(config['queue'].to_s, queues)
            load_schedule_job(name, config)
          else
            Sidekiq.logger.info { "Ignoring #{name}, job's queue is not enabled." }
          end
        end

        Sidekiq.logger.info 'Schedules Loaded'
      else
        Sidekiq.logger.info 'SidekiqScheduler is disabled'
      end
    end

    # Loads a job schedule into the Rufus::Scheduler and stores it in @scheduled_jobs
    def load_schedule_job(name, config)
      # If rails_env is set in the config, enforce ENV['RAILS_ENV'] as
      # required for the jobs to be scheduled.  If rails_env is missing, the
      # job should be scheduled regardless of what ENV['RAILS_ENV'] is set
      # to.
      if config['rails_env'].nil? || rails_env_matches?(config)
        Sidekiq.logger.info "Scheduling #{name} #{config}"
        interval_defined = false
        interval_types = %w(cron every at in interval)
        interval_types.each do |interval_type|
          config_interval_type = config[interval_type]

          if !config_interval_type.nil? && config_interval_type.length > 0

            schedule, options = SidekiqScheduler::RufusUtils.normalize_schedule_options(config_interval_type)

            rufus_job = new_job(name, interval_type, config, schedule, options)
            @scheduled_jobs[name] = rufus_job
            SidekiqScheduler::Utils.update_job_next_time(name, rufus_job.next_time)

            interval_defined = true

            break
          end
        end

        unless interval_defined
          Sidekiq.logger.info "no #{interval_types.join(' / ')} found for #{config['class']} (#{name}) - skipping"
        end
      end
    end

    # Pushes the job into Sidekiq if not already pushed for the given time
    #
    # @param [String] job_name The job's name
    # @param [Time] time The time when the job got cleared for triggering
    # @param [Hash] config Job's config hash
    def idempotent_job_enqueue(job_name, time, config)
      registered = SidekiqScheduler::RedisManager.register_job_instance(job_name, time)

      if registered
        Sidekiq.logger.info "queueing #{config['class']} (#{job_name})"

        handle_errors { enqueue_job(config, time) }

        SidekiqScheduler::RedisManager.remove_elder_job_instances(job_name)
      else
        Sidekiq.logger.debug { "Ignoring #{job_name} job as it has been already enqueued" }
      end
    end

    # Enqueue a job based on a config hash
    #
    # @param job_config [Hash] the job configuration
    # @param time [Time] time the job is enqueued
    def enqueue_job(job_config, time = Time.now)
      config = prepare_arguments(job_config.dup)

      if config.delete('include_metadata')
        config['args'] = arguments_with_metadata(config['args'], scheduled_at: time.to_f)
      end

      if active_job_enqueue?(config['class'])
        SidekiqScheduler::Utils.enqueue_with_active_job(config)
      else
        SidekiqScheduler::Utils.enqueue_with_sidekiq(config)
      end
    end

    def rufus_scheduler_options
      @rufus_scheduler_options ||= {}
    end

    def rufus_scheduler_options=(options)
      @rufus_scheduler_options = options
    end

    def rufus_scheduler
      @rufus_scheduler ||= SidekiqScheduler::Utils.new_rufus_scheduler(rufus_scheduler_options)
    end

    # Stops old rufus scheduler and creates a new one.  Returns the new
    # rufus scheduler
    #
    # @param [Symbol] stop_option The option to be passed to Rufus::Scheduler#stop
    def clear_schedule!(stop_option = :wait)
      if @rufus_scheduler
        @rufus_scheduler.stop(stop_option)
        @rufus_scheduler = nil
      end

      @@scheduled_jobs = {}

      rufus_scheduler
    end

    def reload_schedule!
      if enabled
        Sidekiq.logger.info 'Reloading Schedule'
        clear_schedule!
        load_schedule!
      else
        Sidekiq.logger.info 'SidekiqScheduler is disabled'
      end
    end

    def update_schedule
      last_changed_score, @current_changed_score = @current_changed_score, Time.now.to_f
      schedule_changes = SidekiqScheduler::RedisManager.get_schedule_changes(last_changed_score, @current_changed_score)

      if schedule_changes.size > 0
        Sidekiq.logger.info 'Updating schedule'

        Sidekiq.reload_schedule!
        schedule_changes.each do |schedule_name|
          if Sidekiq.schedule.keys.include?(schedule_name)
            unschedule_job(schedule_name)
            load_schedule_job(schedule_name, Sidekiq.schedule[schedule_name])
          else
            unschedule_job(schedule_name)
          end
        end
        Sidekiq.logger.info 'Schedule updated'
      end
    end

    def job_enabled?(name)
      job = Sidekiq.schedule[name]
      schedule_state(name).fetch('enabled', job.fetch('enabled', true)) if job
    end

    def toggle_job_enabled(name)
      state = schedule_state(name)
      state['enabled'] = !job_enabled?(name)
      set_schedule_state(name, state)
    end

    private

    def new_job(name, interval_type, config, schedule, options)
      options = options.merge({ :job => true, :tags => [name] })

      rufus_scheduler.send(interval_type, schedule, options) do |job, time|
        if job_enabled?(name)
          conf = SidekiqScheduler::Utils.sanitize_job_config(config)

          if job.is_a?(Rufus::Scheduler::CronJob)
            idempotent_job_enqueue(name, calc_cron_run_time(job.cron_line, time.utc), conf)
          else
            idempotent_job_enqueue(name, time, conf)
          end
        end
      end
    end

    def unschedule_job(name)
      if scheduled_jobs[name]
        Sidekiq.logger.debug "Removing schedule #{name}"
        scheduled_jobs[name].unschedule
        scheduled_jobs.delete(name)
      end
    end

    # Retrieves a schedule state
    #
    # @param name [String] with the schedule's name
    # @return [Hash] with the schedule's state
    def schedule_state(name)
      state = SidekiqScheduler::RedisManager.get_job_state(name)

      state ? JSON.parse(state) : {}
    end

    # Saves a schedule state
    #
    # @param name [String] with the schedule's name
    # @param name [Hash] with the schedule's state
    def set_schedule_state(name, state)
      SidekiqScheduler::RedisManager.set_job_state(name, state)
    end

    # Adds a Hash with schedule metadata as the last argument to call the worker.
    # It currently returns the schedule time as a Float number representing the milisencods
    # since epoch.
    #
    # @example with hash argument
    #   arguments_with_metadata({value: 1}, scheduled_at: Time.now)
    #   #=> [{value: 1}, {scheduled_at: <miliseconds since epoch>}]
    #
    # @param args [Array|Hash]
    # @param metadata [Hash]
    # @return [Array] arguments with added metadata
    def arguments_with_metadata(args, metadata)
      if args.is_a? Array
        [*args, metadata]
      else
        [args, metadata]
      end
    end

    def sidekiq_queues
      Sidekiq.options[:queues].map(&:to_s)
    end

    # Returns true if a job's queue is included in the array of queues
    #
    # If queues are empty, returns true.
    #
    # @param [String] job_queue Job's queue name
    # @param [Array<String>] queues
    #
    # @return [Boolean]
    def enabled_queue?(job_queue, queues)
      queues.empty? || queues.include?(job_queue)
    end

    # Returns true if the enqueuing needs to be done for an ActiveJob
    #  class false otherwise.
    #
    # @param [Class] klass the class to check is decendant from ActiveJob
    #
    # @return [Boolean]
    def active_job_enqueue?(klass)
      klass.is_a?(Class) && defined?(ActiveJob::Enqueuing) &&
        klass.included_modules.include?(ActiveJob::Enqueuing)
    end

    # Convert the given arguments in the format expected to be enqueued.
    #
    # @param [Hash] config the options to be converted
    # @option config [String] class the job class
    # @option config [Hash/Array] args the arguments to be passed to the job
    #   class
    #
    # @return [Hash]
    def prepare_arguments(config)
      config['class'] = SidekiqScheduler::Utils.try_to_constantize(config['class'])

      if config['args'].is_a?(Hash)
        config['args'].symbolize_keys! if config['args'].respond_to?(:symbolize_keys!)
      else
        config['args'] = Array(config['args'])
      end

      config
    end

    # Returns true if the given schedule config hash matches the current ENV['RAILS_ENV']
    # @param [Hash] config The schedule job configuration
    #
    # @return [Boolean] true if the schedule config matches the current ENV['RAILS_ENV']
    def rails_env_matches?(config)
      config['rails_env'] && ENV['RAILS_ENV'] && config['rails_env'].gsub(/\s/, '').split(',').include?(ENV['RAILS_ENV'])
    end

    def handle_errors
      begin
        yield
      rescue StandardError => e
        Sidekiq.logger.info "#{e.class.name}: #{e.message}"
      end
    end

    def calc_cron_run_time(cron, time)
      next_t = cron.next_time(time).utc
      previous_t = cron.previous_time(time).utc
      next_diff = next_t - time
      previous_diff = time - previous_t

      if next_diff == previous_diff
        time
      elsif next_diff > previous_diff
        time - previous_diff
      else
        time + next_diff
      end
    end
  end
end
