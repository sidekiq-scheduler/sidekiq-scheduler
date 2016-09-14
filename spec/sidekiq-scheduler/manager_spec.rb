describe SidekiqScheduler::Manager do

  describe '.new' do
    let(:previous_schedule) do
      {
        previous: ScheduleFaker.cron_schedule
      }
    end

    let(:options) do
      {
        enabled: true,
        dynamic: true,
        listened_queues_only: true,
        schedule: { current: ScheduleFaker.cron_schedule( class: 'CurrentJob') }
      }
    end

    before do
      Sidekiq::Scheduler.enabled = nil
      Sidekiq::Scheduler.dynamic = nil
      Sidekiq::Scheduler.listened_queues_only = nil
      Sidekiq.schedule = previous_schedule
    end

    subject { described_class.new(options) }

    it 'sets Sidekiq::Scheduler.enabled flag' do
      expect {
        subject
      }.to change { Sidekiq::Scheduler.enabled }.to(options[:enabled])
    end

    it 'sets Sidekiq::Scheduler.dynamic flag' do
      expect {
        subject
      }.to change { Sidekiq::Scheduler.dynamic }.to(options[:dynamic])
    end

    it 'sets Sidekiq::Scheduler.listened_queues_only flag' do
      expect {
        subject
      }.to change { Sidekiq::Scheduler.listened_queues_only }.to(options[:listened_queues_only])
    end

    it 'sets Sidekiq.schedule' do
      expect {
        subject
      }.to change { Sidekiq.schedule }.to(options[:schedule])
    end

    context 'when no :schedule option' do
      before do
        options.delete(:schedule)
      end

      it 'deletes the previous jobs' do
        expect {
          subject
        }.to change { Sidekiq.schedule }.to({})
      end
    end
  end
end
