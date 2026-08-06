require 'sidekiq-scheduler/job_presenter'

describe SidekiqScheduler::JobPresenter do
  subject(:job_presenter) { described_class.new(job_name, attributes) }

  let(:job_name) { 'job_name' }
  let(:attributes) { {} }

  before { Sidekiq.redis(&:flushall) }

  describe '#next_time' do
    subject { job_presenter.next_time }

    before { SidekiqScheduler::Utils.update_job_next_time(job_name, next_time) }

    context "when the job doesn't have a next time in redis" do
      let(:next_time) { nil }

      it { is_expected.to be_nil }
    end

    context 'when the job has a next time in redis' do
      let(:next_time) { Time.now }

      it { is_expected.to eq(job_presenter.relative_time(next_time)) }
    end
  end

  describe '#last_time' do
    subject { job_presenter.last_time }

    before { SidekiqScheduler::Utils.update_job_last_time(job_name, last_time) }

    context "when the job doesn't have a next time in redis" do
      let(:last_time) { nil }

      it { is_expected.to be_nil }
    end

    context 'when the job has a last time in redis' do
      let(:last_time) { Time.now }

      it { is_expected.to eq(job_presenter.relative_time(last_time)) }
    end
  end

  describe '#interval' do
    subject { job_presenter.interval }

    context 'with "cron" key' do
      let(:attributes) { { 'cron' => 'cron_value' } }

      it { is_expected.to eq('cron_value') }
    end

    context 'with "interval" key' do
      let(:attributes) { { 'interval' => 'interval_value' } }

      it { is_expected.to eq('interval_value') }
    end

    context 'with "every" key' do
      let(:attributes) { { 'every' => 'every_value' } }

      it { is_expected.to eq('every_value') }
    end
  end

  describe '#queue' do
    subject { job_presenter.queue }

    context 'when the attributes have a queue key' do
      let(:attributes) { { 'queue' => 'queue_value' } }

      it { is_expected.to eq('queue_value') }
    end

    context "when the attributes don't have a queue key" do
      it { is_expected.to eq('default') }
    end
  end

  describe '#enabled?' do
    subject { job_presenter.enabled? }

    let(:job_config) { { 'cron' => '* * * * *', 'class' => 'SomeIvarJob', 'args' => '/tmp' } }

    before { Sidekiq.schedule = { job_name => job_config } }

    it { is_expected.to be_truthy }

    context 'when the job is disabled' do
      before { SidekiqScheduler::Scheduler.toggle_job_enabled(job_name) }

      it { is_expected.to be_falsey }
    end
  end

  describe '#[]' do
    let(:params) { 'some params' }

    it 'delegates the method to the attributes' do
      expect(attributes).to receive(:[]).with(params)
      subject[params]
    end
  end

  describe '.build_collection' do
    subject { described_class.build_collection(schedule_hash) }

    context "when there isn't a schedule hash" do
      let(:schedule_hash) { nil }

      it { is_expected.to be_empty }
    end

    context 'when there is a schedule hash' do
      let(:schedule_hash) { { c_job: {}, a_job: {}, b_job: {}, d_job: {} } }

      it "initializes an object with the job's data in alphabetical order" do
        expect(subject.map(&:name)).to eq([:a_job, :b_job, :c_job, :d_job])
      end
    end

    context 'when jobs have stored metadata' do
      let(:schedule_hash) do
        {
          'enabled_job' => { 'enabled' => true },
          'disabled_job' => { 'enabled' => true }
        }
      end
      let(:last_time) { Time.now - 60 }
      let(:next_time) { Time.now + 60 }

      before do
        SidekiqScheduler::RedisManager.set_job_state('disabled_job', 'enabled' => false)
        SidekiqScheduler::RedisManager.set_job_last_time('disabled_job', last_time)
        SidekiqScheduler::RedisManager.set_job_next_time('disabled_job', next_time)
      end

      it 'preloads metadata for every presenter' do
        expect(SidekiqScheduler::RedisManager).to receive(:get_jobs_metadata)
          .once.with(%w(disabled_job enabled_job)).and_call_original

        presenters = subject.to_h { |presenter| [presenter.name, presenter] }

        expect(SidekiqScheduler::RedisManager).not_to receive(:get_job_state)
        expect(SidekiqScheduler::RedisManager).not_to receive(:get_job_last_time)
        expect(SidekiqScheduler::RedisManager).not_to receive(:get_job_next_time)

        expect(presenters.fetch('disabled_job').enabled?).to be(false)
        expect(presenters.fetch('disabled_job').last_time).to eq(job_presenter.relative_time(last_time))
        expect(presenters.fetch('disabled_job').next_time).to eq(job_presenter.relative_time(next_time))
        expect(presenters.fetch('enabled_job').enabled?).to be(true)
      end
    end
  end
end
