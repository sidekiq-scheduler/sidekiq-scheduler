describe SidekiqScheduler::SidekiqAdapter do
  describe ".fetch_scheduler_config_from_sidekiq" do
    subject(:fetch_scheduler_config_from_sidekiq) { 
      config = SConfigWrapper.new      
      described_class.fetch_scheduler_config_from_sidekiq(config.reset!(sidekiq_options))
    }
    
    context "when the 'enabled' option is not under the scheduler option" do
      let(:sidekiq_options) { { enabled: true } }
      
      it do
        expect { fetch_scheduler_config_from_sidekiq }.to raise_error(
          SidekiqScheduler::OptionNotSupportedAnymore,
          ":enabled option should be under the :scheduler: key"
        )
      end
    end

    context "when the 'dynamic' option is not under the scheduler option" do
      let(:sidekiq_options) { { dynamic: true } }
      
      it do
        expect { fetch_scheduler_config_from_sidekiq }.to raise_error(
          SidekiqScheduler::OptionNotSupportedAnymore,
          ":dynamic option should be under the :scheduler: key"
        )
      end
    end

    context "when the 'dynamic_every' option is not under the scheduler option" do
      let(:sidekiq_options) { { dynamic_every: '5s' } }
      
      it do
        expect { fetch_scheduler_config_from_sidekiq }.to raise_error(
          SidekiqScheduler::OptionNotSupportedAnymore,
          ":dynamic_every option should be under the :scheduler: key"
        )
      end
    end

    context "when the 'schedule' option is not under the scheduler option" do
      let(:sidekiq_options) { { schedule: {} } }
      
      it do
        expect { fetch_scheduler_config_from_sidekiq }.to raise_error(
          SidekiqScheduler::OptionNotSupportedAnymore,
          ":schedule option should be under the :scheduler: key"
        )
      end
    end

    context "when the 'listened_queues_only' option is not under the scheduler option" do
      let(:sidekiq_options) { { listened_queues_only: false } }
      
      it do
        expect { fetch_scheduler_config_from_sidekiq }.to raise_error(
          SidekiqScheduler::OptionNotSupportedAnymore,
          ":listened_queues_only option should be under the :scheduler: key"
        )
      end
    end

    context "when the 'rufus_scheduler_options' option is not under the scheduler option" do
      let(:sidekiq_options) { { rufus_scheduler_options: {} } }
      
      it do
        expect { fetch_scheduler_config_from_sidekiq }.to raise_error(
          SidekiqScheduler::OptionNotSupportedAnymore,
          ":rufus_scheduler_options option should be under the :scheduler: key"
        )
      end
    end

    context "when the options are under the :scheduler: key" do
      let(:sidekiq_options) do
        {
          scheduler: {
            enabled: true,
            dynamic: false,
            dynamic_every: '5s',
            listened_queues_only: true,
            schedule: { 'current' => ScheduleFaker.cron_schedule('queue' => 'default') }
          }
        }
      end

      it do
        expect(fetch_scheduler_config_from_sidekiq).to eq(
          {
            enabled: true,
            dynamic: false,
            dynamic_every: '5s',
            listened_queues_only: true,
            schedule: { 'current' => ScheduleFaker.cron_schedule('queue' => 'default') }
          }
        )
      end
    end
  end
end