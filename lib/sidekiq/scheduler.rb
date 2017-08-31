require 'rufus/scheduler'
require 'thwait'
require 'sidekiq/util'
require 'sidekiq-scheduler/manager'
require 'sidekiq-scheduler/rufus_utils'
require 'json'

module Sidekiq
  class Scheduler
    extend Sidekiq::Util

    REGISTERED_JOBS_THRESHOLD_IN_SECONDS = 24 * 60 * 60
    RUFUS_METADATA_KEYS = %w(description at cron every in interval enabled)

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

      # the Rufus::Scheduler jobs that are scheduled
      def scheduled_jobs
        @@scheduled_jobs
      end

      def print_schedule
        if rufus_scheduler
          logger.info "Scheduling Info\tLast Run"
          scheduler_jobs = rufus_scheduler.all_jobs
          scheduler_jobs.each do |_, v|
            logger.info "#{v.t}\t#{v.last}\t"
          end
        end
      end

      # Pulls the schedule from Sidekiq.schedule and loads it into the
      # rufus scheduler instance
      def load_schedule!
        if enabled
          logger.info 'Loading Schedule'

          # Load schedule from redis for the first time if dynamic
          if dynamic
            Sidekiq.reload_schedule!
            @current_changed_score = Time.now.to_f
            rufus_scheduler.every('5s') do
              update_schedule
            end
          end

          logger.info 'Schedule empty! Set Sidekiq.schedule' if Sidekiq.schedule.empty?


          @@scheduled_jobs = {}
          queues = sidekiq_queues

          Sidekiq.schedule.each do |name, config|
            if !listened_queues_only || enabled_queue?(config['queue'].to_s, queues)
              load_schedule_job(name, config)
            else
              logger.info { "Ignoring #{name}, job's queue is not enabled." }
            end
          end

          logger.info 'Schedules Loaded'
        else
          logger.info 'SidekiqScheduler is disabled'
        end
      end

      # Loads a job schedule into the Rufus::Scheduler and stores it in @@scheduled_jobs
      def load_schedule_job(name, config)
        # If rails_env is set in the config, enforce ENV['RAILS_ENV'] as
        # required for the jobs to be scheduled.  If rails_env is missing, the
        # job should be scheduled regardless of what ENV['RAILS_ENV'] is set
        # to.
        if config['rails_env'].nil? || rails_env_matches?(config)
          logger.info "Scheduling #{name} #{config}"
          interval_defined = false
          interval_types = %w{cron every at in interval}
          interval_types.each do |interval_type|
            config_interval_type = config[interval_type]

            if !config_interval_type.nil? && config_interval_type.length > 0

              schedule, options = SidekiqScheduler::RufusUtils.normalize_schedule_options(config_interval_type)

              rufus_job = new_job(name, interval_type, config, schedule, options)
              @@scheduled_jobs[name] = rufus_job
              update_job_next_time(name, rufus_job.next_time)

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
      def idempotent_job_enqueue(job_name, time, config)
        registered = register_job_instance(job_name, time)

        if registered
          logger.info "queueing #{config['class']} (#{job_name})"

          handle_errors { enqueue_job(config, time) }

          remove_elder_job_instances(job_name)
        else
          logger.debug { "Ignoring #{job_name} job as it has been already enqueued" }
        end
      end

      # Pushes job's next time execution
      #
      # @param [String] name The job's name
      # @param [Time] next_time The job's next time execution
      def update_job_next_time(name, next_time)
        Sidekiq.redis do |r|
          next_time ? r.hset(next_times_key, name, next_time) : r.hdel(next_times_key, name)
        end
      end

      # Pushes job's last execution time
      #
      # @param [String] name The job's name
      # @param [Time] last_time The job's last execution time
      def update_job_last_time(name, last_time)
        Sidekiq.redis { |r| r.hset(last_times_key, name, last_time) } if last_time
      end

      # Returns true if the given schedule config hash matches the current
      # ENV['RAILS_ENV']
      def rails_env_matches?(config)
        config['rails_env'] && ENV['RAILS_ENV'] && config['rails_env'].gsub(/\s/, '').split(',').include?(ENV['RAILS_ENV'])
      end

      def handle_errors
        begin
          yield
        rescue StandardError => e
          logger.info "#{e.class.name}: #{e.message}"
        end
      end

      # Enqueue a job based on a config hash
      #
      # @param job_config [Hash] the job configuration
      # @param time [Time] time the job is enqueued
      def enqueue_job(job_config, time=Time.now)
        config = prepare_arguments(job_config.dup)

        if config.delete('include_metadata')
          config['args'] = arguments_with_metadata(config['args'], scheduled_at: time.to_f)
        end

        if active_job_enqueue?(config['class'])
          enqueue_with_active_job(config)
        else
          enqueue_with_sidekiq(config)
        end
      end

      def rufus_scheduler_options
        @rufus_scheduler_options ||= {}
      end

      def rufus_scheduler_options=(options)
        @rufus_scheduler_options = options
      end

      def rufus_scheduler
        @rufus_scheduler ||= new_rufus_scheduler
      end

      # Stops old rufus scheduler and creates a new one.  Returns the new
      # rufus scheduler
      def clear_schedule!
        rufus_scheduler.stop
        @rufus_scheduler = nil
        @@scheduled_jobs = {}
        rufus_scheduler
      end

      def reload_schedule!
        if enabled
          logger.info 'Reloading Schedule'
          clear_schedule!
          load_schedule!
        else
          logger.info 'SidekiqScheduler is disabled'
        end
      end

      def update_schedule
        last_changed_score, @current_changed_score = @current_changed_score, Time.now.to_f
        schedule_changes = Sidekiq.redis do |r|
          r.zrangebyscore :schedules_changed, last_changed_score, "(#{@current_changed_score}"
        end

        if schedule_changes.size > 0
          logger.info 'Updating schedule'
          Sidekiq.reload_schedule!
          schedule_changes.each do |schedule_name|
            if Sidekiq.schedule.keys.include?(schedule_name)
              unschedule_job(schedule_name)
              load_schedule_job(schedule_name, Sidekiq.schedule[schedule_name])
            else
              unschedule_job(schedule_name)
            end
          end
          logger.info 'Schedule updated'
        end
      end

      def unschedule_job(name)
        if scheduled_jobs[name]
          logger.debug "Removing schedule #{name}"
          scheduled_jobs[name].unschedule
          scheduled_jobs.delete(name)
        end
      end

      def enqueue_with_active_job(config)
        options = {
          queue: config['queue']
        }.keep_if { |_, v| !v.nil? }

        initialize_active_job(config['class'], config['args']).enqueue(options)
      end

      def enqueue_with_sidekiq(config)
        Sidekiq::Client.push(sanitize_job_config(config))
      end

      def initialize_active_job(klass, args)
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
        config['class'] = try_to_constantize(config['class'])

        if config['args'].is_a?(Hash)
          config['args'].symbolize_keys! if config['args'].respond_to?(:symbolize_keys!)
        else
          config['args'] = Array(config['args'])
        end

        config
      end

      def try_to_constantize(klass)
        klass.is_a?(String) ? klass.constantize : klass
      rescue NameError
        klass
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

      # Registers a queued job instance
      #
      # @param [String] job_name The job's name
      # @param [Time] time Time at which the job was cleared by the scheduler
      #
      # @return [Boolean] true if the job was registered, false when otherwise
      def register_job_instance(job_name, time)
        pushed_job_key = pushed_job_key(job_name)

        registered, _ = Sidekiq.redis do |r|
          r.pipelined do
            r.zadd(pushed_job_key, time.to_i, time.to_i)
            r.expire(pushed_job_key, REGISTERED_JOBS_THRESHOLD_IN_SECONDS)
          end
        end

        registered
      end

      def remove_elder_job_instances(job_name)
        Sidekiq.redis do |r|
          r.zremrangebyscore(pushed_job_key(job_name), 0, Time.now.to_i - REGISTERED_JOBS_THRESHOLD_IN_SECONDS)
        end
      end

      # Returns the key of the Redis sorted set used to store job enqueues
      #
      # @param [String] job_name The name of the job
      #
      # @return [String]
      def pushed_job_key(job_name)
        "sidekiq-scheduler:pushed:#{job_name}"
      end

      # Returns the key of the Redis hash for job's execution times hash
      #
      # @return [String] with the key
      def next_times_key
        'sidekiq-scheduler:next_times'
      end

      # Returns the key of the Redis hash for job's last execution times hash
      #
      # @return [String] with the key
      def last_times_key
        'sidekiq-scheduler:last_times'
      end

      # Returns the Redis's key for saving schedule states.
      #
      # @return [String] with the key
      def schedules_state_key
        'sidekiq-scheduler:states'
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

      def new_rufus_scheduler
        Rufus::Scheduler.new(rufus_scheduler_options).tap do |scheduler|
          scheduler.define_singleton_method(:on_post_trigger) do |job, triggered_time|
            Sidekiq::Scheduler.update_job_last_time(job.tags[0], triggered_time)
            Sidekiq::Scheduler.update_job_next_time(job.tags[0], job.next_time)
          end
        end
      end

      def new_job(name, interval_type, config, schedule, options)
        options = options.merge({ :job => true, :tags => [name] })

        rufus_scheduler.send(interval_type, schedule, options) do |job, time|
          idempotent_job_enqueue(name, time, sanitize_job_config(config)) if job_enabled?(name)
        end
      end

      def sanitize_job_config(config)
        config.reject { |k, _| RUFUS_METADATA_KEYS.include?(k) }
      end

      # Retrieves a schedule state
      #
      # @param name [String] with the schedule's name
      # @return [Hash] with the schedule's state
      def schedule_state(name)
        state = Sidekiq.redis { |r| r.hget(schedules_state_key, name) }

        state ? JSON.parse(state) : {}
      end

      # Saves a schedule state
      #
      # @param name [String] with the schedule's name
      # @param name [Hash] with the schedule's state
      def set_schedule_state(name, state)
        Sidekiq.redis { |r| r.hset(schedules_state_key, name, JSON.generate(state)) }
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
    end
  end
end
