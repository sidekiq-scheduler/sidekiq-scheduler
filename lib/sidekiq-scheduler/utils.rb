require 'set'

module SidekiqScheduler
  module Utils

    RUFUS_METADATA_KEYS = %w(description at cron every in interval enabled)

    # Stringify keys belonging to a hash.
    #
    # Also stringifies nested keys and keys of hashes inside arrays, and sets
    #
    # @param [Object] object
    #
    # @return [Object]
    def self.stringify_keys(object)
      if object.is_a?(Hash)
        Hash[[*object.map { |k, v| [k.to_s, stringify_keys(v) ]} ]]

      elsif object.is_a?(Array) || object.is_a?(Set)
        object.map { |v| stringify_keys(v) }

      else
        object
      end
    end

    # Symbolize keys belonging to a hash.
    #
    # Also symbolizes nested keys and keys of hashes inside arrays, and sets
    #
    # @param [Object] object
    #
    # @return [Object]
    def self.symbolize_keys(object)
      if object.is_a?(Hash)
        Hash[[*object.map { |k, v| [k.to_sym, symbolize_keys(v) ]} ]]

      elsif object.is_a?(Array) || object.is_a?(Set)
        object.map { |v| symbolize_keys(v) }

      else
        object
      end
    end

    # Constantize a given string.
    #
    # @param [String] klass The string to constantize
    #
    # @return [Class] the class corresponding to the klass param
    def self.try_to_constantize(klass)
      klass.is_a?(String) ? Object.const_get(klass) : klass
    rescue NameError
      klass
    end

    # Initializes active_job using the passed parameters.
    #
    # @param [Class] klass The class to initialize
    # @param [Array, Hash] args The parameters passed to the klass initializer
    #
    # @return [Object] instance of the class klass
    def self.initialize_active_job(klass, args, keyword_argument = false)
      if args.is_a?(Array)
        klass.new(*args)
      elsif args.is_a?(Hash) && keyword_argument
        klass.new(**symbolize_keys(args))
      else
        klass.new(args)
      end
    end

    # Returns true if the enqueuing needs to be done for an ActiveJob
    #  class false otherwise.
    #
    # @param [Class] klass the class to check is descendant from ActiveJob
    #
    # @return [Boolean]
    def self.active_job_enqueue?(klass)
      klass.is_a?(Class) && defined?(ActiveJob::Enqueuing) &&
        klass.included_modules.include?(ActiveJob::Enqueuing)
    end

    # Enqueues the job using the Sidekiq client.
    #
    # @param [Hash] config The job configuration
    def self.enqueue_with_sidekiq(config)
      Sidekiq::Client.push(sanitize_job_config(config))
    end

    # Enqueues the job using the ActiveJob.
    #
    # @param [Hash] config The job configuration
    def self.enqueue_with_active_job(config)
      options = {
        queue: config['queue']
      }.keep_if { |_, v| !v.nil? }

      initialize_active_job(config['class'], config['args'], config['keyword_argument']).enqueue(options)
    end

    # Removes the hash values associated to the rufus metadata keys.
    #
    # @param [Hash] config The job configuration
    #
    # @return [Hash] the sanitized job config
    def self.sanitize_job_config(config)
      config.reject { |k, _| RUFUS_METADATA_KEYS.include?(k) }
    end

    # Creates a new instance of rufus scheduler.
    #
    # @return [Rufus::Scheduler] the scheduler instance
    def self.new_rufus_scheduler(options = {})
      Rufus::Scheduler.new(options).tap do |scheduler|
        scheduler.define_singleton_method(:on_post_trigger) do |job, triggered_time|
          if (job_name = job.tags[0])
            SidekiqScheduler::Utils.update_job_last_time(job_name, triggered_time)
            SidekiqScheduler::Utils.update_job_next_time(job_name, job.next_time)
          end
        end
      end
    end

    # Pushes job's next time execution
    #
    # @param [String] name The job's name
    # @param [Time] next_time The job's next time execution
    def self.update_job_next_time(name, next_time)
      if next_time
        SidekiqScheduler::RedisManager.set_job_next_time(name, next_time)
      else
        SidekiqScheduler::RedisManager.remove_job_next_time(name)
      end
    end

    # Pushes job's last execution time
    #
    # @param [String] name The job's name
    # @param [Time] last_time The job's last execution time
    def self.update_job_last_time(name, last_time)
      SidekiqScheduler::RedisManager.set_job_last_time(name, last_time) if last_time
    end

    # Try to figure out when the cron job was supposed to run.
    #
    # Rufus calls the scheduler block with the current time and not the time the block was scheduled to run.
    # This means under certain conditions you could have a job get scheduled multiple times because `time.to_i` is used
    # to key the job in redis. If one server is under load and Rufus tries to run the jobs 1 seconds after the other
    # server then the job will be queued twice.
    # This method essentially makes a best guess at when this job was supposed to run and return that.
    #
    # @param [Fugit::Cron] cron
    # @param [Time] time
    #
    # @return [Time]
    def self.calc_cron_run_time(cron, time)
      time = time.floor # remove sub seconds to prevent rounding errors.
      return time if cron.match?(time) # If the time is a perfect match then return it.

      next_t = cron.next_time(time).to_t
      previous_t = cron.previous_time(time).to_t
      # The `time` var is some point between `previous_t` and `next_t`.
      # Figure out how far off we are from each side in seconds.
      next_diff = next_t - time
      previous_diff = time - previous_t

      if next_diff == previous_diff
        # In the event `time` is exactly between `previous_t` and `next_t` the diff will not be equal to
        # `cron.rough_frequency`. In that case we round down.
        cron.rough_frequency == next_diff ? time : previous_t
      elsif next_diff > previous_diff
        # We are closer to the previous run time so return that.
        previous_t
      else
        # We are closer to the next run time so return that.
        next_t
      end
    end
  end
end
