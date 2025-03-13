module SidekiqScheduler
  class OptionNotSupportedAnymore < StandardError; end

  class SidekiqAdapter
    SIDEKIQ_GTE_7_3_0 = Gem::Version.new(Sidekiq::VERSION) >= Gem::Version.new('7.3.0')

    def self.fetch_scheduler_config_from_sidekiq(sidekiq_config)
      return {} if sidekiq_config.nil?

      check_using_old_sidekiq_scheduler_config!(sidekiq_config)

      sidekiq_config.fetch(:scheduler, {})
    end

    def self.check_using_old_sidekiq_scheduler_config!(sidekiq_config)
      %i[enabled dynamic dynamic_every schedule listened_queues_only rufus_scheduler_options].each do |option|
        if sidekiq_config.key?(option)
          raise OptionNotSupportedAnymore, ":#{option} option should be under the :scheduler: key"
        end
      end
    end

    def self.start_schedule_manager(sidekiq_config:, schedule_manager:)
      sidekiq_config[:schedule_manager] = schedule_manager
      sidekiq_config[:schedule_manager].start
    end

    def self.stop_schedule_manager(sidekiq_config:)
      sidekiq_config[:schedule_manager].stop
    end

    def self.sidekiq_queues(sidekiq_config)
      if sidekiq_config.nil? || (sidekiq_config.respond_to?(:empty?) && sidekiq_config.empty?)
        Sidekiq.instance_variable_get(:@config).queues.map(&:to_s)
      else
        sidekiq_config.queues.map(&:to_s)
      end
    end

    def self.redis_key_exists?(key_name)
      Sidekiq.redis do |r|
        r.exists(key_name) > 0
      end
    end

    def self.redis_zrangebyscore(key, from, to)
      Sidekiq.redis do |r|
        r.zrange(key, from, to, "BYSCORE")
      end
    end
  end
end
