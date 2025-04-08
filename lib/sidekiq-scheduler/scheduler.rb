require 'rufus/scheduler'
require 'json'
require 'sidekiq-scheduler/rufus_utils'
require 'sidekiq-scheduler/redis_manager'
require 'sidekiq-scheduler/config'

module SidekiqScheduler
  class Scheduler
    # We expect rufus jobs to have #params
    Rufus::Scheduler::Job.module_eval do
      alias_method :params, :opts
    end

    # TODO: Can we remove those attr_accessor's? If we need to keep them, we should
    # update those values on the config object instead of just here in the scheduler.
    # That's why we need to do what we do in the set_current_scheduler_options (not
    # saying we will have to do it somehow still)
    #
    # NOTE: ^ Keeping this TODO here for now, in a future version of this project
    # we will remove those attr accessors and use only our config object. For now,
    # let's keep as it is.

    # Set to enable or disable the scheduler.
    attr_accessor :enabled

    # Set to update the schedule in runtime in a given time period.
    attr_accessor :dynamic

    # Set to update the schedule in runtime dynamically per this period.
    attr_accessor :dynamic_every

    # Set to schedule jobs only when will be pushed to queues listened by sidekiq
    attr_accessor :listened_queues_only

    # Set custom options for rufus scheduler, like max_work_threads.
    attr_accessor :rufus_scheduler_options

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

    def initialize(config = SidekiqScheduler::Config.new(without_defaults: true))
      @scheduler_config = config

      self.enabled = config.enabled?
      self.dynamic = config.dynamic?
      self.dynamic_every = config.dynamic_every?
      self.listened_queues_only = config.listened_queues_only?
      self.rufus_scheduler_options = config.rufus_scheduler_options || {}
    end

    # the Rufus::Scheduler jobs that are scheduled
    def scheduled_jobs
      @scheduled_jobs
    end

    def print_schedule
      if rufus_scheduler
        Sidekiq.logger.info "Scheduling Info\tLast Run"
        scheduler_jobs = rufus_scheduler.jobs
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
        queues = scheduler_config.sidekiq_queues

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
            return unless rufus_job

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
        config['args'] = arguments_with_metadata(config['args'], "scheduled_at" => time.to_f.round(3))
      end

      if SidekiqScheduler::Utils.active_job_enqueue?(config['class'])
        SidekiqScheduler::Utils.enqueue_with_active_job(config)
      else
        SidekiqScheduler::Utils.enqueue_with_sidekiq(config)
      end
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

      @scheduled_jobs = {}

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

    def toggle_all_jobs(new_state)
      Sidekiq.schedule!.keys.each do |name|
        state = schedule_state(name)
        state['enabled'] = new_state
        set_schedule_state(name, state)
      end
    end

    def to_hash
      {
        scheduler_config: @scheduler_config.to_hash
      }
    end

    def inspect
      "#<SidekiqScheduler::Scheduler enabled=#{enabled} dynamic=#{dynamic} dynamic_every=#{dynamic_every} listened_queues_only=#{listened_queues_only} rufus_scheduler_options=#{rufus_scheduler_options}>"
    end

    private

    attr_reader :scheduler_config

    def new_job(name, interval_type, config, schedule, options)
      options = options.merge({ :job => true, :tags => [name] })

      rufus_scheduler.send(interval_type, schedule, options) do |job, time|
        if job_enabled?(name)
          conf = SidekiqScheduler::Utils.sanitize_job_config(config)

          if job.is_a?(Rufus::Scheduler::CronJob)
            idempotent_job_enqueue(name, SidekiqScheduler::Utils.calc_cron_run_time(job.cron_line, time.to_t), conf)
          else
            idempotent_job_enqueue(name, time.to_t, conf)
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
    # @param state [Hash] with the schedule's state
    def set_schedule_state(name, state)
      SidekiqScheduler::RedisManager.set_job_state(name, state)
    end

    # Adds a Hash with schedule metadata as the last argument to call the worker.
    # It currently returns the schedule time as a Float number representing the milliseconds
    # since epoch.
    #
    # @example with hash argument
    #   arguments_with_metadata({value: 1}, scheduled_at: Time.now.round(3))
    #   #=> [{value: 1}, {scheduled_at: <milliseconds since epoch>}]
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
  end
end
