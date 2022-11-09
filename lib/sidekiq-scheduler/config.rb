module SidekiqScheduler
  class Config
    # We have to set the default as nil because the scheduler could be instantiated without
    # passing the sidekiq config, and in those scenarios we don't want to fail
    def initialize(sidekiq_config: nil, without_defaults: false)
      @sidekiq_config = sidekiq_config
      @scheduler_config = fetch_scheduler_config(sidekiq_config, without_defaults)
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
      SidekiqScheduler::SidekiqAdapter.sidekiq_queues(sidekiq_config)
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

    def fetch_scheduler_config(sidekiq_config, without_defaults)
      conf = SidekiqScheduler::SidekiqAdapter.fetch_scheduler_config_from_sidekiq(sidekiq_config)
      without_defaults ? conf : DEFAULT_OPTIONS.merge(conf)
    end
  end
end
