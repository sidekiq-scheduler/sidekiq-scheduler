describe SidekiqScheduler::SidekiqAdapter do
  describe ".fetch_scheduler_config_from_sidekiq" do
    subject(:fetch_scheduler_config_from_sidekiq) { 
      config = SConfigWrapper.new      
      described_class.fetch_scheduler_config_from_sidekiq(config.reset!(sidekiq_options))
    }

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