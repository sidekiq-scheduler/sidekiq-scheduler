describe SidekiqScheduler::Schedule do
  before { Sidekiq.redis(&:flushall) }

  describe '.schedule=' do
    subject { Sidekiq.schedule = { job_id => schedule } }

    let(:job_id) { 'super_job' }
    let(:schedule) { ScheduleFaker.default_options }

    before { SidekiqScheduler::Scheduler.dynamic = true }

    it 'sets the schedule on redis' do
      subject

      job = SidekiqScheduler::Store.job_from_redis(job_id)

      expect(job).to eq(schedule)
    end

    context 'when "class" argument is not set' do
      let(:job_id) { 'SomeWorker' }

      before { schedule.reject! { |key| key == 'class' } }

      it 'uses job name as "class" argument' do
        subject

        job = SidekiqScheduler::Store.job_from_redis(job_id)

        expect(job).to eq(schedule.merge('class' => job_id))
        expect(job['class']).to eq(job_id)
      end
    end

    context 'when using symbol keys' do
      let(:job_id) { :worker }
      let(:schedule) { { class: 'SomeWorker', every: '20s', queue: 'low', description: 'symbols' } }

      it 'converts them into strings' do
        subject

        expect(Sidekiq.schedule).to eq({
          'worker' => {
            'class' => 'SomeWorker', 'every' => '20s', 'queue' => 'low', 'description' => 'symbols'
          }
        })
      end

      context 'when schedule is set twice' do
        let(:schedule) { ScheduleFaker.default_options }

        it 'sets the schedule on redis' do
          2.times { subject }

          expect(SidekiqScheduler::Store.job_from_redis(job_id)).to eq(schedule)
        end
      end
    end

    context 'when job is a sidekiq job' do
      let(:job_id) { 'system_notifier' }
      let(:schedule) { { 'class' => 'SystemNotifierWorker' } }

      it 'infers the queue name' do
        subject

        expect(SidekiqScheduler::Store.job_from_redis(job_id)['queue']).to eq('system')
      end
    end

    context 'when job is an ActiveJob job' do
      let(:job_id) { 'email_sender' }
      let(:schedule) { { 'class' => 'EmailSender' } }

      it 'does not set the queue name' do
        subject

        expect(SidekiqScheduler::Store.job_from_redis(job_id)['queue']).to eq(nil)
      end
    end
  end

  describe '.set_schedule' do
    let(:job_id) { 'super_job' }
    let(:schedule) { ScheduleFaker.default_options }

    it 'set_schedule can set an individual schedule' do
      Sidekiq.set_schedule(job_id, schedule)

      expect(SidekiqScheduler::Store.job_from_redis(job_id)).to eq(schedule)
      expect(SidekiqScheduler::Store.changed_job?(job_id)).to be_truthy
    end
  end

  describe '.get_schedule' do
    subject { Sidekiq.get_schedule(args) }

    context 'when schedules are previously set' do
      let(:job_id) { 'super_job' }
      let(:schedule) { ScheduleFaker.default_options }

      before { Sidekiq.set_schedule(job_id, schedule) }

      context 'when name is given' do
        let(:args) { 'super_job' }

        it { is_expected.to eq(SidekiqScheduler::Store.job_from_redis(job_id)) }
      end

      context 'when name is not given' do
        let(:args) {}

        it { is_expected.to include(job_id => SidekiqScheduler::Store.job_from_redis(job_id)) }
      end
    end

    context 'when no schedules are previously set' do
      context 'when name is given' do
        let(:args) { 'super_job' }

        it { is_expected.to be_nil }
      end

      context 'when name is not given' do
        let(:args) {}

        it { is_expected.to be_empty }
      end
    end
  end

  describe '.remove_schedule' do
    let(:job_id) { 'super_job' }
    let(:schedule) { ScheduleFaker.default_options }

    before { Sidekiq.set_schedule(job_id, schedule) }

    it 'removes a schedule from redis' do
      Sidekiq.remove_schedule(job_id)

      expect(SidekiqScheduler::Store.job_from_redis_without_decoding(job_id)).to be_nil
      expect(SidekiqScheduler::Store.changed_job?(job_id)).to be_truthy
    end
  end
end
