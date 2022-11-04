module SidekiqScheduler
  class Config
    # We have to set the default as nil because the scheduler could be instantiated without
    # passing the sidekiq config, and in those scenarios we don't want to fail
    def initialize(sidekiq_config = nil)
      @sidekiq_config = sidekiq_config
      @scheduler_config = DEFAULT_OPTIONS.merge(fetch_scheduler_config(sidekiq_config))
    end

    def enabled?
      scheduler_config[:enabled]
    end

    def enabled=(value)
      scheduler_config[:enabled] = value
    end

    def dynamic?
      scheduler_config[:dynamic]
    end

    def dynamic=(value)
      scheduler_config[:dynamic] = value
    end

    def dynamic_every?
      scheduler_config[:dynamic_every]
    end

    def dynamic_every=(value)
      scheduler_config[:dynamic_every] = value
    end

    def schedule
      scheduler_config[:schedule]
    end

    def schedule=(value)
      scheduler_config[:schedule] = value
    end

    def listened_queues_only?
      scheduler_config[:listened_queues_only]
    end

    def listened_queues_only=(value)
      scheduler_config[:listened_queues_only] = value
    end

    def rufus_scheduler_options
      scheduler_config[:rufus_scheduler_options]
    end

    def rufus_scheduler_options=(value)
      scheduler_config[:rufus_scheduler_options] = value
    end

    def sidekiq_queues
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

    private

    attr_reader :scheduler_config
    attr_reader :sidekiq_config

    DEFAULT_OPTIONS = {
      enabled: true,
      dynamic: false,
      dynamic_every: '5s',
      schedule: {},
      rufus_scheduler_options: {}
    }.freeze

    def fetch_scheduler_config(sidekiq_config)
      return {} if sidekiq_config.nil?

      if SIDEKIQ_GTE_6_5_0
        sidekiq_config.fetch(:scheduler, {})
      else
        sidekiq_config.options.fetch(:scheduler, {})
      end
    end
  end  
end