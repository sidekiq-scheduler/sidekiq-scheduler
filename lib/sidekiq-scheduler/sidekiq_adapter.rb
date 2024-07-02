module SidekiqScheduler
  class OptionNotSupportedAnymore < StandardError; end

  class SidekiqAdapter
    SIDEKIQ_GTE_6_5_0 = Gem::Version.new(Sidekiq::VERSION) >= Gem::Version.new('6.5.0')
    SIDEKIQ_GTE_7_0_0 = Gem::Version.new(Sidekiq::VERSION) >= Gem::Version.new('7.0.0')
    SIDEKIQ_GTE_7_3_0 = Gem::Version.new(Sidekiq::VERSION) >= Gem::Version.new('7.3.0')

    def self.fetch_scheduler_config_from_sidekiq(sidekiq_config)
      return {} if sidekiq_config.nil?

      check_using_old_sidekiq_scheduler_config!(sidekiq_config)

      if SIDEKIQ_GTE_6_5_0
        sidekiq_config.fetch(:scheduler, {})
      else
        sidekiq_config.options.fetch(:scheduler, {})
      end
    end

    def self.check_using_old_sidekiq_scheduler_config!(sidekiq_config)
      %i[enabled dynamic dynamic_every schedule listened_queues_only rufus_scheduler_options].each do |option|
        if SIDEKIQ_GTE_7_0_0
          if sidekiq_config.key?(option)
            raise OptionNotSupportedAnymore, ":#{option} option should be under the :scheduler: key"
          end
        elsif SIDEKIQ_GTE_6_5_0
          unless sidekiq_config[option].nil?
            raise OptionNotSupportedAnymore, ":#{option} option should be under the :scheduler: key"
          end
        else
          if sidekiq_config.options.key?(option)
            raise OptionNotSupportedAnymore, ":#{option} option should be under the :scheduler: key"
          end
        end
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
        if sidekiq_config.nil? || (sidekiq_config.respond_to?(:empty?) && sidekiq_config.empty?)
          Sidekiq.instance_variable_get(:@config).queues.map(&:to_s)
        else
          sidekiq_config.queues.map(&:to_s)
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

    def self.redis_zrangebyscore(key, from, to)
      Sidekiq.redis do |r|
        if SIDEKIQ_GTE_7_0_0
          r.zrange(key, from, to, "BYSCORE")
        else
          r.zrangebyscore(key, from, to)
        end
      end
    end
  end
end
