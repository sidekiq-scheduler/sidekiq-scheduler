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
      let(:schedule_hash) { { first_job_name: {}, second_job_name: {} } }

      it "initializes an object with the job's data" do
        expect(subject.map(&:name)).to eq([:first_job_name, :second_job_name])
      end
    end
  end
end
