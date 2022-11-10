module SidekiqScheduler
  class SidekiqAdapter
    def self.fetch_scheduler_config_from_sidekiq(sidekiq_config)
      return {} if sidekiq_config.nil?

      if SIDEKIQ_GTE_6_5_0
        sidekiq_config.fetch(:scheduler, {})
      else
        sidekiq_config.options.fetch(:scheduler, {})
      end
    end

    def self.start_schedule_manager(sidekiq_config:, schedule_manager:)
      if SIDEKIQ_GTE_6_5_0
        sidekiq_config[:schedule_manager] = schedule_manager
        sidekiq_config[:schedule_manager].start
      else
        sidekiq_config.options[:schedule_manager] = schedule_manager
        sidekiq_config.options[:schedule_manager].start
      end
    end

    def self.stop_schedule_manager(sidekiq_config:)
      if SIDEKIQ_GTE_6_5_0
        sidekiq_config[:schedule_manager].stop
      else
        sidekiq_config.options[:schedule_manager].stop
      end
    end

    def self.sidekiq_queues(sidekiq_config)
      if SIDEKIQ_GTE_7_0_0
        if sidekiq_config.present?
          sidekiq_config.queues.map(&:to_s)
        else
          Sidekiq.instance_variable_get(:@config).queues.map(&:to_s)
        end
      elsif SIDEKIQ_GTE_6_5_0
        Sidekiq[:queues].map(&:to_s)
      else
        Sidekiq.options[:queues].map(&:to_s)
      end
    end

    def self.redis_key_exists?(key_name)
      Sidekiq.redis do |r|
        if SIDEKIQ_GTE_7_0_0
          r.exists(key_name) > 0
        else
          r.exists?(key_name)
        end
      end
    end
  end
end
