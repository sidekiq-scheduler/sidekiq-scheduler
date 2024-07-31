require 'sidekiq-scheduler/utils'

describe SidekiqScheduler::Utils do

  describe '.stringify_keys' do
    subject { described_class.stringify_keys(object) }

    context 'with a Hash' do
      let(:object) do
        {
          some_symbol_key: 'symbol',
          'some_string_key' => 'string',
          [1, 2] => 'object',
          nesting: {
            level_1: {
              level_2: 2,
            }
          }
        }
      end

      let(:expected) do
        {
          'some_symbol_key' => 'symbol',
          'some_string_key' => 'string',
          '[1, 2]' => 'object',
          'nesting' => {
            'level_1' => {
              'level_2' => 2,
            }
          }
        }
      end

      it { is_expected.to eq(expected) }
    end

    context 'with an Array' do
      let(:object) do
        [
          1,
          2,
          'a string',
          :a_symbol,
          {
            'some_string_key' => 'string',
            nesting: {
              level_1: {
                level_2: 2,
              }
            }
          }
        ]
      end

      let(:expected) do
        [
          1,
          2,
          'a string',
          :a_symbol,
          {
            'some_string_key' => 'string',
            'nesting' => {
              'level_1' => {
                'level_2' => 2,
              }
            }
          }
        ]
      end

      it { is_expected.to eq(expected) }
    end

    context 'with some other object' do
      let(:object) { Object.new }
      let(:expected) { object }

      it { is_expected.to eq(expected) }
    end
  end

  describe '.symbolize_keys' do
    subject { described_class.symbolize_keys(object) }

    context 'with a Hash' do
      let(:object) do
        {
          some_symbol_key: 'symbol',
          'some_string_key' => 'string',
          'nesting': {
            'level_1': {
              'level_2': 2,
            }
          }
        }
      end

      let(:expected) do
        {
          some_symbol_key: 'symbol',
          some_string_key: 'string',
          nesting: {
            level_1: {
              level_2: 2,
            }
          }
        }
      end

      it { is_expected.to eq(expected) }
    end

    context 'with an Array' do
      let(:object) do
        [
          1,
          2,
          'a string',
          :a_symbol,
          {
            some_symbol_key: 'symbol',
            'nesting' => {
              'level_1' => {
                'level_2' => 2,
              }
            }
          }
        ]
      end

      let(:expected) do
        [
          1,
          2,
          'a string',
          :a_symbol,
          {
            some_symbol_key: 'symbol',
            nesting: {
              level_1: {
                level_2: 2,
              }
            }
          }
        ]
      end

      it { is_expected.to eq(expected) }
    end

    context 'with some other object' do
      let(:object) { Object.new }
      let(:expected) { object }

      it { is_expected.to eq(expected) }
    end
  end

  describe '.try_to_constantize' do
    subject { described_class.try_to_constantize(klass) }

    let(:klass) { 'SomeClass' }

    before { class SomeClass; end }

    it { is_expected.to eql(SomeClass) }

    context 'when the parameter is already a constant' do
      let(:klass) { SomeClass }

      it { is_expected.to eql(SomeClass) }
    end

    context 'when the class passed by parameter is not defined' do
      let(:klass) { 'OtherClass' }

      it { is_expected.to eql('OtherClass') }
    end
  end

  describe '.initialize_active_job' do
    subject { described_class.initialize_active_job(klass, args) }

    let(:klass) { EmailSender }

    describe 'when the object has no arguments' do
      let(:args) { [] }

      it 'should be correctly initialized' do
        expect(klass).to receive(:new).with(no_args).and_call_original

        expect(subject).to be_instance_of(klass)
      end
    end

    describe 'when the object has a hash as an argument' do
      let (:args) { { testing: 'Argument' } }

      it 'should be correctly initialized' do
        expect(klass).to receive(:new).with(args).and_call_original

        expect(subject).to be_instance_of(klass)
      end
    end

    describe 'when the object has many arguments' do
      let (:args) { ['one', 'two'] }

      it 'should be correctly initialized' do
        expect(klass).to receive(:new).with(*args).and_call_original

        expect(subject).to be_instance_of(klass)
      end
    end
  end

  describe '.enqueue_with_sidekiq' do
    subject { described_class.enqueue_with_sidekiq(config) }

    let(:base_config) { JobConfigurationsFaker.some_worker }
    let(:config) { base_config }

    it 'enqueues a job into a sidekiq queue' do
      expect { subject }.to change { Sidekiq::Queues[config['queue']].size }.by(1)
    end

    context 'when the config have rufus related keys' do
      let(:config) { base_config.merge(described_class::RUFUS_METADATA_KEYS.sample => 'value') }

      it 'removes those keys' do
        expect(Sidekiq::Client).to receive(:push).with(base_config)
        subject
      end
    end
  end

  describe '.enqueue_with_active_job' do
    subject { described_class.enqueue_with_active_job(config) }

    let(:config) { { 'class' => job, 'args' => args, 'queue' => queue } }
    let(:job) { EmailSender }
    let(:args) { [] }
    let(:queue) { nil }

    it 'with no args' do
      expect(EmailSender).to receive(:new).with(no_args).twice.and_call_original

      subject

      expect(subject).to have_attributes(arguments: args, queue_name: 'email')
    end

    context 'with args' do
      let(:job) { AddressUpdater }
      let(:args) { [100] }

      it 'should be correctly enqueued' do
        expect(AddressUpdater).to receive(:new).with(100).and_call_original
        expect(AddressUpdater).to receive(:new).with(no_args).and_call_original

        expect(subject).to have_attributes(arguments: args, queue_name: 'default')
      end
    end

    context 'with keyword args' do
      let(:config) { { 'class' => job, 'args' => args, 'queue' => queue, 'keyword_argument' => true } }
      let(:args) { { 'foo' => 'bar', 'hello' => 'world' } }
      let(:job) { AddressUpdaterKeyword }

      it 'should be correctly enqueued with keyword arguments' do
        expect(AddressUpdaterKeyword).to receive(:new).with(foo: 'bar', hello: 'world').and_call_original
        expect(AddressUpdaterKeyword).to receive(:new).with(no_args).and_call_original

        expect(subject).to have_attributes(arguments: [args.symbolize_keys], queue_name: 'default')
      end
    end

    context 'with queue name set by config' do
      let(:queue) { 'critical' }

      it 'should be correctly enqueued' do
        expect(EmailSender).to receive(:new).with(no_args).twice.and_call_original

        subject

        expect(subject).to have_attributes(arguments: args, queue_name: queue)
      end
    end
  end

  describe '.sanitize_job_config' do
    subject { described_class.sanitize_job_config(config) }

    let(:base_config) { JobConfigurationsFaker.some_worker }
    let(:config) { base_config }

    it { is_expected.to eql(base_config) }

    context 'when the config have rufus related keys' do
      let(:config) { base_config.merge(described_class::RUFUS_METADATA_KEYS.sample => 'value') }

      it { is_expected.to eql(base_config) }
    end
  end

  describe '.new_rufus_scheduler' do
    subject { described_class.new_rufus_scheduler(options) }

    let(:options) { {} }
    let(:job) { double('job', tags: ['tag'], next_time: 'next_time') }

    it 'sets a trigger to update the next execution time for the jobs' do
      expect(described_class).to receive(:update_job_next_time)
        .with(job.tags[0], job.next_time)

      subject.on_post_trigger(job, 'triggered_time')
    end

    it 'sets a trigger to update the last execution time for the jobs' do
      expect(described_class).to receive(:update_job_last_time)
        .with(job.tags[0], 'triggered_time')

      subject.on_post_trigger(job, 'triggered_time')
    end

    context 'when passing options' do
      let(:options) { { lockfile: '/tmp/rufus_lock' } }

      it 'should pass the options to the rufus scheduler initializer' do
        expect(Rufus::Scheduler).to receive(:new).with(options)
        subject
      end
    end
  end

  describe '.update_job_next_time' do
    subject { described_class.update_job_next_time(job_name, next_time) }

    let(:job_name) { 'job_name' }

    context 'when the next time is nil' do
      let(:next_time) { nil }

      it "deletes the job's next time from redis" do
        subject
        job_next_time = SidekiqScheduler::Store.job_next_execution_time(job_name)

        expect(job_next_time).not_to be
      end
    end

    context 'when the next time is present' do
      let(:next_time) { 'next_time' }

      it 'adds the value to redis for the job' do
        subject
        job_next_time = SidekiqScheduler::Store.job_next_execution_time(job_name)

        expect(job_next_time).to eq(next_time)
      end
    end
  end

  describe '.update_job_last_time' do
    subject { described_class.update_job_last_time(job_name, last_time) }

    let(:job_name) { 'job_name' }
    let(:last_time) { 'last_time' }

    it 'should add the last time value to redis for the job' do
      subject
      job_last_time = SidekiqScheduler::Store.job_last_execution_time(job_name)

      expect(job_last_time).to eq(last_time)
    end

    context 'when last_time is nil' do
      let(:last_time) { nil }

      it { is_expected.to be_nil }
    end
  end

  describe '.calc_cron_run_time' do
    context 'when running every minute' do
      let(:cron) { Fugit::Cron.do_parse('* * * * *') }

      context 'when run at exact time' do
        let(:time) { Time.new(2024, 1, 1, 9, 0, 0) }

        it 'returns the current time' do
          expect(described_class.calc_cron_run_time(cron, time)).to eq(time)
        end
      end

      context 'when exactly between previous and next run' do
        # every minute would mean 30 seconds is between next and previous run
        let(:time) { Time.new(2024, 1, 1, 9, 0, 30) }

        it 'returns the previous time' do
          expect(described_class.calc_cron_run_time(cron, time)).to eq(cron.previous_time(time).to_t)
        end
      end

      context 'when running before previous run' do
        let(:time) { Time.new(2024, 1, 1, 8, 59, 58) }

        it 'returns next run' do
          expect(described_class.calc_cron_run_time(cron, time)).to eq(cron.next_time(time).to_t)
        end
      end

      context 'when closer to next run' do
        let(:time) { Time.new(2024, 1, 1, 9, 0, 31) }

        it 'returns next run' do
          expect(described_class.calc_cron_run_time(cron, time)).to eq(cron.next_time(time).to_t)
        end
      end

      context 'when closer to previous run' do
        let(:time) { Time.new(2024, 1, 1, 9, 0, 29) }

        it 'returns previous run' do
          expect(described_class.calc_cron_run_time(cron, time)).to eq(cron.previous_time(time).to_t)
        end
      end
    end

    context 'when running every hour' do
      let(:cron) { Fugit::Cron.do_parse('0 */1 * * *') }

      context 'when run at exact time' do
        let(:time) { Time.new(2024, 1, 1, 9, 0, 0) }

        it 'returns the current time' do
          expect(described_class.calc_cron_run_time(cron, time)).to eq(time)
        end
      end

      context 'when exactly between previous and next run' do
        # every hour would mean 30 minutes is between next and previous run
        let(:time) { Time.new(2024, 1, 1, 9, 30) }

        it 'returns the previous time' do
          expect(described_class.calc_cron_run_time(cron, time)).to eq(cron.previous_time(time).to_t)
        end
      end

      context 'when running before previous run' do
        let(:time) { Time.new(2024, 1, 1, 8, 59, 59) }

        it 'returns next run' do
          expect(described_class.calc_cron_run_time(cron, time)).to eq(cron.next_time(time).to_t)
        end
      end

      context 'when closer to next run' do
        let(:time) { Time.new(2024, 1, 1, 9, 30, 1) } # 1 second after

        it 'returns next run' do
          expect(described_class.calc_cron_run_time(cron, time)).to eq(cron.next_time(time).to_t)
        end
      end

      context 'when closer to previous run' do
        let(:time) { Time.new(2024, 1, 1, 9, 29, 59) } # 1 second off

        it 'returns previous run' do
          expect(described_class.calc_cron_run_time(cron, time)).to eq(cron.previous_time(time).to_t)
        end
      end
    end

    context 'when running aperiodically' do
      context 'when a time zone is set' do
        let(:cron) { Fugit::Cron.do_parse('0 8-18 * * * Asia/Tokyo') }

        context 'when run at exact time' do
          # Tokyo is +9 hours from UTC
          let(:time) { Time.new(2024, 1, 1, 8, 0, 0, '+09:00') }

          it 'returns the current time' do
            expect(described_class.calc_cron_run_time(cron, time)).to eq(time)
          end
        end

        context 'when exactly between previous and next run' do
          # 1AM is 7 hours from 8AM and 6PM
          let(:time) { Time.new(2024, 1, 1, 1, 0, 0, '+09:00') }

          it 'returns the previous time' do
            expect(described_class.calc_cron_run_time(cron, time)).to eq(cron.previous_time(time).to_t)
          end
        end

        context 'when running before previous run' do
          let(:time) { Time.new(2024, 1, 1, 7, 59, 59, '+09:00') }

          it 'returns next run' do
            expect(described_class.calc_cron_run_time(cron, time)).to eq(cron.next_time(time).to_t)
          end
        end

        context 'when closer to next run' do
          let(:time) { Time.new(2024, 1, 1, 8, 30, 1, '+09:00') } # 1 second after

          it 'returns next run' do
            expect(described_class.calc_cron_run_time(cron, time)).to eq(cron.next_time(time).to_t)
          end
        end

        context 'when closer to previous run' do
          let(:time) { Time.new(2024, 1, 1, 17, 29, 59, '+09:00') } # 1 second off

          it 'returns previous run' do
            expect(described_class.calc_cron_run_time(cron, time)).to eq(cron.previous_time(time).to_t)
          end
        end
      end

      context 'when a time zone is not set' do
        let(:cron) { Fugit::Cron.do_parse('0 8-18 * * *') }

        context 'when run at exact time' do
          let(:time) { Time.new(2024, 1, 1, 8, 0, 0) }

          it 'returns the current time' do
            expect(described_class.calc_cron_run_time(cron, time)).to eq(time)
          end
        end

        context 'when exactly between previous and next run' do
          # 1AM is 7 hours from 8AM and 6PM
          let(:time) { Time.new(2024, 1, 1, 1, 0, 0) }

          it 'returns the previous time' do
            expect(described_class.calc_cron_run_time(cron, time)).to eq(cron.previous_time(time).to_t)
          end
        end

        context 'when running before previous run' do
          let(:time) { Time.new(2024, 1, 1, 7, 59, 59) }

          it 'returns next run' do
            expect(described_class.calc_cron_run_time(cron, time)).to eq(cron.next_time(time).to_t)
          end
        end

        context 'when closer to next run' do
          let(:time) { Time.new(2024, 1, 1, 8, 30, 1) } # 1 second after

          it 'returns next run' do
            expect(described_class.calc_cron_run_time(cron, time)).to eq(cron.next_time(time).to_t)
          end
        end

        context 'when closer to previous run' do
          let(:time) { Time.new(2024, 1, 1, 17, 29, 59) } # 1 second off

          it 'returns previous run' do
            expect(described_class.calc_cron_run_time(cron, time)).to eq(cron.previous_time(time).to_t)
          end
        end
      end
    end
  end
end
