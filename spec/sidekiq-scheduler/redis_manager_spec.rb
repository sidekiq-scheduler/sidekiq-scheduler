require 'sidekiq-scheduler/redis_manager'

describe SidekiqScheduler::RedisManager do

  before { SidekiqScheduler::Store.clean }

  describe '.get_job_schedule' do
    subject { described_class.get_job_schedule(job_name) }

    let(:job_name) { 'some_job' }
    let(:schedule) { JSON.generate(ScheduleFaker.default_options) }

    before { SidekiqScheduler::Store.hset(:schedules, job_name, schedule) }

    it { is_expected.to eq(schedule) }
  end

  describe '.get_job_state' do
    subject { described_class.get_job_state(job_name) }

    let(:job_name) { 'some_job' }
    let(:state) { JSON.generate('enabled' => true) }

    before { SidekiqScheduler::Store.hset('sidekiq-scheduler:states', job_name, state) }

    it { is_expected.to eq(state) }
  end

  describe '.get_job_next_time' do
    subject { described_class.get_job_next_time(job_name) }

    let(:job_name) { 'some_job' }
    let(:next_time) { 'some_time' }

    before { SidekiqScheduler::Store.hset('sidekiq-scheduler:next_times', job_name, next_time) }

    it { is_expected.to eq(next_time) }
  end

  describe '.get_job_last_time' do
    subject { described_class.get_job_last_time(job_name) }

    let(:job_name) { 'some_job' }
    let(:last_time) { 'some_time' }

    before { SidekiqScheduler::Store.hset('sidekiq-scheduler:last_times', job_name, last_time) }

    it { is_expected.to eq(last_time) }
  end

  describe '.set_job_schedule' do
    subject { described_class.set_job_schedule(job_name, config) }

    let(:job_name) { 'some_job' }
    let(:config) { ScheduleFaker.default_options }

    it 'should store the job schedule' do
      subject

      stored_schedule = SidekiqScheduler::Store.hget(:schedules, job_name)
      expect(JSON.parse(stored_schedule)).to eq(config)
    end
  end

  describe '.set_job_state' do
    subject { described_class.set_job_state(job_name, state) }

    let(:job_name) { 'some_job' }
    let(:state) { { 'enabled' => true } }

    it 'should store the job state' do
      subject

      stored_state = SidekiqScheduler::Store.hget('sidekiq-scheduler:states', job_name)
      expect(JSON.parse(stored_state)).to eq(state)
    end
  end

  describe '.set_job_next_time' do
    subject { described_class.set_job_next_time(job_name, next_time) }

    let(:job_name) { 'some_job' }
    let(:next_time) { 'some_time' }

    it 'should store the job next_time' do
      subject

      stored_next_time = SidekiqScheduler::Store.hget('sidekiq-scheduler:next_times', job_name)
      expect(stored_next_time).to eq(next_time)
    end
  end

  describe '.set_job_last_time' do
    subject { described_class.set_job_last_time(job_name, last_time) }

    let(:job_name) { 'some_job' }
    let(:last_time) { 'some_time' }

    it 'should store the job last_time' do
      subject

      stored_last_time = SidekiqScheduler::Store.hget('sidekiq-scheduler:last_times', job_name)
      expect(stored_last_time).to eq(last_time)
    end
  end

  describe '.remove_job_schedule' do
    subject { described_class.remove_job_schedule(job_name) }

    let(:job_name) { 'some_job' }
    let(:schedule) { JSON.generate(ScheduleFaker.default_options) }

    before { SidekiqScheduler::Store.hset(:schedules, job_name, schedule) }

    it 'should remove the job schedule' do
      subject

      stored_schedule = SidekiqScheduler::Store.hget(:schedules, job_name)
      expect(stored_schedule).to be_nil
    end

    context "when the job schedule doesn't exist" do
      let(:job_name) { 'job_without_schedule' }

      it 'should maintain inexisting' do
        subject

        stored_schedule = SidekiqScheduler::Store.hget(:schedules, job_name)
        expect(stored_schedule).to be_nil
      end
    end
  end

  describe '.remove_job_next_time' do
    subject { described_class.remove_job_next_time(job_name) }

    let(:job_name) { 'some_job' }
    let(:next_time) { 'some_time' }

    before { SidekiqScheduler::Store.hset('sidekiq-scheduler:next_times', job_name, next_time) }

    it 'should remove the job next_time' do
      subject

      stored_next_time = SidekiqScheduler::Store.hget('sidekiq-scheduler:next_times', job_name)
      expect(stored_next_time).to be_nil
    end

    context "when the job next_time doesn't exist" do
      let(:job_name) { 'job_without_next_time' }

      it 'should maintain inexisting' do
        subject

        stored_next_time = SidekiqScheduler::Store.hget('sidekiq-scheduler:next_times', job_name)
        expect(stored_next_time).to be_nil
      end
    end
  end

  describe '.get_all_schedules' do
    subject { described_class.get_all_schedules }

    let(:some_job) { 'some_job' }
    let(:some_job_schedule) { JSON.generate(ScheduleFaker.default_options) }
    let(:other_job) { 'other_job' }
    let(:other_job_schedule) { JSON.generate(ScheduleFaker.every_schedule) }

    before do
      SidekiqScheduler::Store.hset(:schedules, some_job, some_job_schedule)
      SidekiqScheduler::Store.hset(:schedules, other_job, other_job_schedule)
    end

    it { is_expected.to include('some_job' => some_job_schedule, 'other_job' => other_job_schedule) }
    it { expect(subject.count).to eql(2) }
  end

  describe '.schedule_exist?' do
    subject { described_class.schedule_exist? }

    it { is_expected.to be_falsey }

    context 'when some job schedule exists' do
      let(:schedule) { JSON.generate(ScheduleFaker.default_options) }

      before { SidekiqScheduler::Store.hset(:schedules, 'some_job', schedule) }

      it { is_expected.to be_truthy }
    end
  end

  describe '.get_schedule_changes' do
    subject { described_class.get_schedule_changes(from, to) }

    let(:current_time) { Time.now }

    let(:from) { (current_time - (5 * 60)).to_f }
    let(:to) { current_time.to_f }

    let(:job_one) { 'job_one' }
    let(:job_two) { 'job_two' }
    let(:job_three) { 'job_three' }
    let(:job_one_changed_time) { current_time - (4 * 60) }
    let(:job_two_changed_time) { current_time - (3 * 60) }
    let(:job_three_changed_time) { current_time - (2 * 60) }

    before do
      SidekiqScheduler::Store.zadd(:schedules_changed, job_one_changed_time.to_f, job_one)
      SidekiqScheduler::Store.zadd(:schedules_changed, job_two_changed_time.to_f, job_two)
      SidekiqScheduler::Store.zadd(:schedules_changed, job_three_changed_time.to_f, job_three)
    end

    it 'should return all changed jobs names in the range' do
      Timecop.freeze(current_time) do
        is_expected.to match_array(%w(job_one job_two job_three))
      end
    end

    context 'when there are changes outside of the range' do
      let(:job_one_changed_time) { current_time - (6 * 60) }
      let(:job_three_changed_time) { current_time + (1 * 60) }

      it 'should return only the changed jobs names in the range' do
        Timecop.freeze(current_time) do
          is_expected.to match_array(%w(job_two))
        end
      end
    end

    context 'when there are changes in the range limits' do
      let(:job_one_changed_time) { current_time - (5 * 60) }
      let(:job_three_changed_time) { current_time }

      it 'should return only the changed jobs names inside the range or in the lower bound' do
        Timecop.freeze(current_time) do
          is_expected.to match_array(%w(job_one job_two))
        end
      end
    end
  end

  describe '.add_schedule_change' do
    subject { described_class.add_schedule_change(job_name) }

    let(:job_name) { 'some_job' }

    it 'should store the schedule change with the current time as score' do
      Timecop.freeze(Time.now) do
        subject

        stored_schedules_changes = SidekiqScheduler::Store.zrangebyscore('schedules_changed', Time.now.to_f, Time.now.to_f)
        expect(stored_schedules_changes).to match_array(%w[some_job])
      end
    end
  end

  describe '.clean_schedules_changed' do
    subject { described_class.clean_schedules_changed }

    before { SidekiqScheduler::Store.zadd('schedules_changed', Time.now.to_f, 'some_job') }

    it "shouldn't remove the schedules_changed if it's sorted set" do
      subject

      expect(SidekiqScheduler::Store.exists?('schedules_changed')).to be true
    end

    context 'when schedules_changed is not a sorted set' do
      before do
        SidekiqScheduler::Store.clean
        SidekiqScheduler::Store.sadd('schedules_changed', 'some_job')
      end

      it 'should remove the schedules_changed set' do
        subject

        expect(SidekiqScheduler::Store.exists?('schedules_changed')).to be false
      end
    end
  end

  describe '.register_job_instance' do
    subject { described_class.register_job_instance(job_name, time) }

    let(:current_time) { Time.now }
    let(:job_name) { 'some_job' }
    let(:time) { current_time }

    it { expect(subject).to be_truthy }

    it 'should store the job instance' do
      subject

      expect(SidekiqScheduler::Store.zrange('sidekiq-scheduler:pushed:some_job', 0, -1)).to eql([time.to_i.to_s])
    end

    it 'should add an expiration key' do
      subject

      Timecop.travel(SidekiqScheduler::RedisManager::REGISTERED_JOBS_THRESHOLD_IN_SECONDS) do
        expect(SidekiqScheduler::Store.exists?('sidekiq-scheduler:pushed:some_job')).to be false
      end
    end

    context 'when job instance is already registered' do
      before { described_class.register_job_instance(job_name, current_time) }

      it { is_expected.to be_falsey }

      context 'when registering the new instance with a different time' do
        let(:time) { current_time + 1 }

        it { is_expected.to be_truthy }
      end
    end
  end

  describe '.remove_elder_job_instances' do
    subject { described_class.remove_elder_job_instances(job_name) }

    let(:current_time) { Time.now }
    let(:job_name) { 'some_job' }
    let(:job_key) { 'sidekiq-scheduler:pushed:some_job' }
    let(:job_instance) { current_time.to_i }
    let(:other_job_instance) { (current_time - (20 * 60)).to_i }
    let(:old_job_instance) { (current_time - SidekiqScheduler::RedisManager::REGISTERED_JOBS_THRESHOLD_IN_SECONDS).to_i }

    before do
      SidekiqScheduler::Store.zadd(job_key, job_instance, job_instance)
      SidekiqScheduler::Store.zadd(job_key, other_job_instance, other_job_instance)
      SidekiqScheduler::Store.zadd(job_key, old_job_instance, old_job_instance)
    end

    it 'should remove the elder instances' do
      subject

      expect(SidekiqScheduler::Store.zrange(job_key, 0, -1)).to match_array([job_instance.to_s, other_job_instance.to_s])
    end
  end

  describe '.pushed_job_key' do
    subject { described_class.pushed_job_key(job_name) }

    let(:job_name) { 'some_job' }

    it { is_expected.to eq('sidekiq-scheduler:pushed:some_job') }
  end

  describe '.next_times_key' do
    subject { described_class.next_times_key }

    it { is_expected.to eq('sidekiq-scheduler:next_times') }
  end

  describe '.last_times_key' do
    subject { described_class.last_times_key }

    it { is_expected.to eq('sidekiq-scheduler:last_times') }
  end

  describe '.schedules_state_key' do
    subject { described_class.schedules_state_key }

    it { is_expected.to eq('sidekiq-scheduler:states') }
  end
end
