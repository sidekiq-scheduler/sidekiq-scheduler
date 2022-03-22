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
      klass.is_a?(String) ? klass.constantize : klass
    rescue NameError
      klass
    end

    # Initializes active_job using the passed parameters.
    #
    # @param [Class] klass The class to initialize
    # @param [Array/Hash] the parameters passed to the klass initializer
    #
    # @return [Object] instance of the class klass
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

      initialize_active_job(config['class'], config['args']).enqueue(options)
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
          SidekiqScheduler::Utils.update_job_last_time(job.tags[0], triggered_time)
          SidekiqScheduler::Utils.update_job_next_time(job.tags[0], job.next_time)
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
  end
end
