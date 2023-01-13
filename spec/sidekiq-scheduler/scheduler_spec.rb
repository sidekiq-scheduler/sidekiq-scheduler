describe SidekiqScheduler::Scheduler do
  let(:scheduler_options) do
    {
      scheduler: {
        enabled: true,
        dynamic: false,
        dynamic_every: '5s',
        listened_queues_only: false,
        rufus_scheduler_options: { max_work_threads: 5 }
      }
    }
  end
  let(:scheduler_config) { SidekiqScheduler::Config.new(sidekiq_config: @sconfig.reset!(scheduler_options)) }
  let(:instance) { described_class.new(scheduler_config) }

  before do
    @sconfig = SConfigWrapper.new
    described_class.instance = instance
    Sidekiq.redis(&:flushall)
    instance.instance_variable_set(:@scheduled_jobs, {})
    Sidekiq::Worker.clear_all
    Sidekiq.schedule = {}
  end

  after do
    instance.clear_schedule!
  end

  describe '.new' do
    subject { described_class.new(scheduler_config) }

    let(:scheduler_options) do
      {
        scheduler: {
          enabled: true,
          dynamic: false,
          dynamic_every: '5s',
          listened_queues_only: false,
          rufus_scheduler_options: { max_work_threads: 5 }
        }
      }
    end

    it { expect(subject.enabled).to be_truthy }

    it { expect(subject.dynamic).to be_falsey }

    it { expect(subject.dynamic_every).to eql('5s') }

    it { expect(subject.listened_queues_only).to be_falsey }

    it { expect(subject.rufus_scheduler_options).to eql({ max_work_threads: 5 }) }

    context 'when passing rufus_scheduler_options' do
      it { expect(instance.rufus_scheduler.max_work_threads).to eql(5) }
    end

    context 'when passing no options' do
      subject { described_class.new }

      it { expect(subject.enabled).to be_nil }

      it { expect(subject.dynamic).to be_nil }

      it { expect(subject.dynamic_every).to be_nil }

      it { expect(subject.listened_queues_only).to be_nil }

      it { expect(subject.rufus_scheduler_options).to be_nil }
    end
  end

  describe '.instance' do
    subject { described_class.instance }

    context 'when instance is not set' do
      before { described_class.instance_variable_set(:@instance, nil) }

      it 'should create a new instance' do
        expect(SidekiqScheduler::Scheduler).to receive(:new)
        subject
      end

      describe 'scheduler instance' do
        it { is_expected.to be_a(SidekiqScheduler::Scheduler) }

        it { expect(subject.enabled).to be_nil }

        it { expect(subject.dynamic).to be_nil }

        it { expect(subject.dynamic_every).to be_nil }

        it { expect(subject.listened_queues_only).to be_nil }
      end
    end
  end

  describe '.instance=' do
    subject { described_class.instance = value }

    let(:value) do
      described_class.new(
        SidekiqScheduler::Config.new(
          sidekiq_config: sidekiq_config_for_options(
            {
              scheduler: {
                enabled: true,
                dynamic: false
              }
            }
          )
        )
      )
    end

    it 'should set the passed instance' do
      subject
      expect(described_class.instance).to eql(value)
    end

    describe 'scheduler instance' do
      it { is_expected.to be_a(SidekiqScheduler::Scheduler) }

      it { expect(subject.enabled).to be_truthy }

      it { expect(subject.dynamic).to be_falsey }

      it { expect(subject.dynamic_every).to eq(SidekiqScheduler::Config::DEFAULT_OPTIONS[:dynamic_every]) }

      it { expect(subject.listened_queues_only).to be_nil }
    end
  end

  describe '#enqueue_job' do
    subject { instance.enqueue_job(scheduled_job_config, schedule_time) }

    let(:schedule_time) { Time.now }
    let(:args) { '/tmp' }
    let(:scheduled_job_config) do
      { 'class' => 'SomeWorker', 'queue' => 'high', 'args' => args, 'cron' => '* * * * *' }
    end

    # The job should be loaded, since a missing rails_env means ALL envs.
    before { ENV['RAILS_ENV'] = 'test' }

    context 'when it is a sidekiq worker' do
      it 'prepares the parameters' do
        expect(Sidekiq::Client).to receive(:push).with({
                                                         'class' => SomeWorker,
                                                         'queue' => 'high',
                                                         'args' => ['/tmp']
                                                       })

        subject
      end
    end

    context 'when it is an activejob worker' do
      before { scheduled_job_config['class'] = EmailSender }

      it 'enqueues the job as active job' do
        expect(EmailSender).to receive(:new).with('/tmp')
                                            .and_return(double(:job).as_null_object)
        subject
      end

      specify 'enqueue to the configured queue' do
        expect_any_instance_of(EmailSender).to receive(:enqueue).with(queue: 'high')
        subject
      end

      context 'when queue is not configured' do
        before { scheduled_job_config.delete('queue') }

        it 'does not include :queue option' do
          expect_any_instance_of(EmailSender).to receive(:enqueue).with({})
          subject
        end
      end
    end

    context 'when worker class does not exist' do
      before { scheduled_job_config['class'] = 'NonExistentWorker' }

      it 'prepares the parameters' do
        expect(Sidekiq::Client).to receive(:push).with({
                                                         'class' => 'NonExistentWorker',
                                                         'queue' => 'high',
                                                         'args' => ['/tmp']
                                                       })

        subject
      end
    end

    context 'when job is configured to receive metadata' do
      before { scheduled_job_config['include_metadata'] = true }

      context 'when called without a time argument' do
        it 'uses the current time' do
          Timecop.freeze(schedule_time) do
            expect(Sidekiq::Client).to receive(:push).with({
                                                             'class' => SomeWorker,
                                                             'queue' => 'high',
                                                             'args' => ['/tmp',
                                                                        { 'scheduled_at' => schedule_time.to_f.round(3) }]
                                                           })

            subject
          end
        end
      end

      context 'when arguments are already expanded' do
        it 'pushes the job with the metadata as the last argument' do
          Timecop.freeze(schedule_time) do
            expect(Sidekiq::Client).to receive(:push).with({
                                                             'class' => SomeWorker,
                                                             'queue' => 'high',
                                                             'args' => ['/tmp',
                                                                        { 'scheduled_at' => schedule_time.to_f.round(3) }]
                                                           })

            subject
          end
        end
      end

      context 'when it is an active job worker' do
        before { scheduled_job_config['class'] = EmailSender }

        it 'enqueues the job as active job' do
          expect(EmailSender).to receive(:new).with(
            '/tmp',
            { 'scheduled_at' => schedule_time.to_f.round(3) }
          ).and_return(double(:job).as_null_object)

          subject
        end

        specify 'enqueue to the configured queue' do
          expect_any_instance_of(EmailSender).to receive(:enqueue).with(queue: 'high')
          subject
        end
      end

      context 'when arguments contain a hash' do
        let(:args) { { 'dir' => '/tmp' } }

        it 'pushes the job with the metadata as the last argument' do
          Timecop.freeze(schedule_time) do
            expect(Sidekiq::Client).to receive(:push).with({
                                                             'class' => SomeWorker,
                                                             'queue' => 'high',
                                                             'args' => [{ dir: '/tmp' },
                                                                        { 'scheduled_at' => schedule_time.to_f.round(3) }]
                                                           })

            subject
          end
        end
      end

      context 'when arguments are empty' do
        before { scheduled_job_config.delete('args') }

        it 'pushes the job with the metadata as the only argument' do
          Timecop.freeze(schedule_time) do
            expect(Sidekiq::Client).to receive(:push).with({
                                                             'class' => SomeWorker,
                                                             'queue' => 'high',
                                                             'args' => [{ 'scheduled_at' => schedule_time.to_f.round(3) }]
                                                           })

            subject
          end
        end
      end
    end
  end

  describe 'clear_schedule!' do
    it 'sets a new rufus-scheduler instance' do
      expect do
        instance.clear_schedule!
      end.to change { instance.rufus_scheduler }
    end

    it 'stops the current rufus-scheduler' do
      expect(instance.rufus_scheduler).to receive(:stop).with(:wait)

      instance.clear_schedule!
    end

    it 'forwards stop_option to Rufus::Scheduler#stop' do
      stop_option = :kill

      expect(instance.rufus_scheduler).to receive(:stop).with(stop_option)

      instance.clear_schedule!(stop_option)
    end
  end

  describe '#load_schedule!' do
    subject { instance.load_schedule! }

    let(:schedule) do
      {
        'some_ivar_job' => {
          'cron' => '* * * * *',
          'class' => class_name,
          'args' => args,
          'queue' => queue
        }
      }
    end
    let(:class_name) { 'SomeWorker' }
    let(:args) { '/tmp' }
    let(:queue) { nil }

    before { Sidekiq.schedule = schedule }

    it 'should correctly load the job into rufus_scheduler' do
      expect { subject }.to change { instance.rufus_scheduler.jobs.size }.from(0).to(1)
      expect(instance.scheduled_jobs).to include('some_ivar_job')
    end

    context 'when job has a configured queue' do
      let(:class_name) { 'ReportWorker' }
      let(:queue) { 'reporting' }

      context 'when listened_queues_only flag is active' do
        before { instance.listened_queues_only = true }

        context 'when default sidekiq queues' do
          before { @sconfig.queues = [] }

          it 'loads the job into the scheduler' do
            subject
            expect(instance.scheduled_jobs).to include('some_ivar_job')
          end
        end

        context "when sidekiq queues match job's one" do
          before { @sconfig.queues = ['reporting'] }

          it 'loads the job into the scheduler' do
            subject
            expect(instance.scheduled_jobs).to include('some_ivar_job')
          end
        end

        context "when stringified sidekiq queues match symbolized job's one" do
          let(:queue) { :reporting }

          before { @sconfig.queues = ['reporting'] }

          it 'loads the job into the scheduler' do
            subject
            expect(instance.scheduled_jobs).to include('some_ivar_job')
          end
        end

        context "when symbolized sidekiq queues match stringified job's one" do
          let(:queue) { 'reporting' }

          before { @sconfig.queues = [:reporting] }

          it 'loads the job into the scheduler' do
            subject
            expect(instance.scheduled_jobs).to include('some_ivar_job')
          end
        end

        context "when sidekiq queues does not match job's one" do
          before { @sconfig.queues = ['mailing'] }

          it 'does not load the job into the scheduler' do
            subject
            expect(instance.scheduled_jobs).to_not include('some_ivar_job')
          end
        end
      end

      context 'when listened_queues_only flag is inactive' do
        before { instance.listened_queues_only = false }

        context "when sidekiq queues does not match job's one" do
          before { @sconfig.queues = ['mailing'] }

          it 'loads the job into the scheduler' do
            subject
            expect(instance.scheduled_jobs).to include('some_ivar_job')
          end
        end
      end
    end

    context 'when job has no configured queue' do
      let(:queue) { nil }

      context 'when listened_queues_only flag is active' do
        before { instance.listened_queues_only = true }

        context 'when configured sidekiq queues' do
          before { @sconfig.queues = ['mailing'] }

          it 'does not load the job into the scheduler' do
            subject
            expect(instance.scheduled_jobs).to_not include('some_ivar_job')
          end
        end

        context 'when default sidekiq queues' do
          before { @sconfig.queues = [] }

          it 'loads the job into the scheduler' do
            subject
            expect(instance.scheduled_jobs).to include('some_ivar_job')
          end
        end
      end

      context 'when listened_queues_only flag is false' do
        before { instance.listened_queues_only = false }

        context 'when configured sidekiq queues' do
          before { @sconfig.queues = ['mailing'] }

          it 'loads the job into the scheduler' do
            subject
            expect(instance.scheduled_jobs).to include('some_ivar_job')
          end
        end
      end
    end

    context 'when the enabled option is false' do
      let(:scheduler_options) do
        {
          scheduler: {
            enabled: false,
            dynamic: false,
            dynamic_every: '5s',
            listened_queues_only: false
          }
        }
      end

      let(:job_schedule) do
        {
          'some_ivar_job' => {
            'cron' => '* * * * *',
            'class' => 'SomeIvarJob',
            'args' => '/tmp'
          }
        }
      end

      before { Sidekiq.schedule = job_schedule }

      it 'does not increase the jobs ammount' do
        subject
        expect(instance.rufus_scheduler.jobs.size).to equal(0)
      end

      it 'does not add the job to the scheduled jobs' do
        subject
        expect(instance.scheduled_jobs).not_to include('some_ivar_job')
      end
    end
  end

  describe '#reload_schedule!' do
    subject { instance.reload_schedule! }

    let(:scheduler_options) do
      {
        scheduler: {
          enabled: true,
          dynamic: true,
          dynamic_every: '5s',
          listened_queues_only: false
        }
      }
    end

    context 'when setting new values' do
      before do
        instance.load_schedule!
        SidekiqScheduler::Store.del(SidekiqScheduler::RedisManager.schedules_key)
        SidekiqScheduler::Store.hset(
          SidekiqScheduler::RedisManager.schedules_key,
          'some_ivar_job2',
          JSON.generate(
            cron: '* * * * *',
            class: 'SomeWorker',
            args: '/tmp/2'
          )
        )
      end

      it 'should include them' do
        expect { subject }.to change { instance.scheduled_jobs.include?('some_ivar_job2') }.to(true)
      end
    end

    context 'when not re-including values' do
      before do
        Sidekiq.schedule = {
          'some_ivar_job' => {
            'cron' => '* * * * *',
            'class' => 'SomeWorker',
            'args' => '/tmp'
          }
        }
        instance.load_schedule!
        SidekiqScheduler::Store.del(SidekiqScheduler::RedisManager.schedules_key)
      end

      it 'should remove them' do
        expect { subject }.to change { instance.scheduled_jobs.include?('some_ivar_job') }.to(false)
      end
    end

    context 'when dynamic option is configured' do
      context 'when dynamic option is set by default to 5s' do
        before do
          Sidekiq.set_schedule('some_job', ScheduleFaker.cron_schedule('args' => '/tmp'))
          instance.load_schedule!
          Sidekiq.set_schedule('other_job', ScheduleFaker.cron_schedule('args' => 'sample'))
        end

        it 'reloads the schedule from redis after 5 seconds' do
          expect do
            Timecop.travel(7 * 60)
            sleep 0.5
          end.to change { instance.scheduled_jobs.include?('other_job') }.to(true)
        end
      end

      context 'when dynamic_every is set to 5m' do
        let(:scheduler_options) do
          {
            scheduler: {
              enabled: true,
              dynamic: true,
              dynamic_every: '5m',
              listened_queues_only: false
            }
          }
        end

        before do
          Sidekiq.set_schedule('some_job', ScheduleFaker.cron_schedule('args' => '/tmp'))
          instance.load_schedule!
          Sidekiq.set_schedule('other_job', ScheduleFaker.cron_schedule('args' => 'sample'))
        end

        it 'does not reload the schedule from redis after 2 minutes' do
          expect do
            Timecop.travel(2 * 60)
            sleep 0.5
          end.to_not change { instance.scheduled_jobs.include?('other_job') }
        end

        it 'reloads the schedule from redis after 10 minutes' do
          expect do
            Timecop.travel(10 * 60)
            sleep 0.5
          end.to change { instance.scheduled_jobs.include?('other_job') }.to(true)
        end
      end
    end
  end

  describe '#load_schedule_job' do
    subject { instance.load_schedule_job(job_name, config) }

    let(:job_name) { 'some_job' }
    let(:config) { ScheduleFaker.invalid_schedule }
    let(:next_time_execution) do
      SidekiqScheduler::Store.hexists(SidekiqScheduler::RedisManager.next_times_key, job_name)
    end

    before { subject }

    context 'without a timing option' do
      it 'does not put the job inside the scheduled hash' do
        expect(instance.scheduled_jobs.keys).to be_empty
      end

      it 'does not add the job to rufus scheduler' do
        expect(instance.rufus_scheduler.jobs.size).to be_zero
      end

      it 'does not store the next time execution correctly' do
        expect(next_time_execution).not_to be
      end
    end

    context 'cron schedule' do
      context 'without options' do
        let(:config) { ScheduleFaker.cron_schedule }

        it 'adds the job to rufus scheduler' do
          expect(instance.rufus_scheduler.jobs.size).to be(1)
        end

        it 'puts the job inside the scheduled hash' do
          expect(instance.scheduled_jobs.keys).to eq([job_name])
        end

        it 'stores the next time execution correctly' do
          expect(next_time_execution).to be
        end

        it 'sets a tag for the job with the name' do
          expect(instance.scheduled_jobs[job_name].tags).to eq([job_name])
        end
      end

      context 'with options' do
        context 'when the options are valid' do
          let(:config) { ScheduleFaker.cron_schedule('allow_overlapping' => 'true') }

          it 'adds the job to rufus scheduler' do
            expect(instance.rufus_scheduler.jobs.size).to be(1)
          end

          it 'puts the job inside the scheduled hash' do
            expect(instance.scheduled_jobs.keys).to eq([job_name])
          end

          it 'sets the default options' do
            expect(instance.scheduled_jobs[job_name].params.keys).to include(:allow_overlapping)
          end

          it 'stores the next time execution correctly' do
            expect(next_time_execution).to be
          end
        end

        context 'when the cron is empty' do
          let(:config) { ScheduleFaker.cron_schedule('cron' => '') }

          it 'does not put the job inside the scheduled hash' do
            expect(instance.scheduled_jobs.keys).to be_empty
          end

          it 'does not add the job to rufus scheduler' do
            expect(instance.rufus_scheduler.jobs.size).to be(0)
          end

          it 'does not store the next time execution correctly' do
            expect(next_time_execution).not_to be
          end
        end
      end
    end

    context 'every schedule' do
      context 'without options' do
        let(:config) { ScheduleFaker.every_schedule }

        it 'adds the job to rufus scheduler' do
          expect(instance.rufus_scheduler.jobs.size).to be(1)
        end

        it 'puts the job inside the scheduled hash' do
          expect(instance.scheduled_jobs.keys).to eq([job_name])
        end

        it 'stores the next time execution correctly' do
          expect(next_time_execution).to be
        end
      end

      context 'with options' do
        let(:config) { ScheduleFaker.every_schedule('first_in' => '60s') }

        it 'adds the job to rufus scheduler' do
          expect(instance.rufus_scheduler.jobs.size).to be(1)
        end

        it 'puts the job inside the scheduled hash' do
          expect(instance.scheduled_jobs.keys).to eq([job_name])
        end

        it 'sets the default options' do
          expect(instance.scheduled_jobs[job_name].params.keys).to include(:first_in)
        end

        it 'stores the next time execution correctly' do
          expect(next_time_execution).to be
        end
      end
    end

    context 'at schedule' do
      let(:config) { ScheduleFaker.at_schedule(at: Time.now + 60) }

      it 'adds the job to rufus scheduler' do
        expect(instance.rufus_scheduler.jobs.size).to eq(1)
      end

      it 'puts the job inside the scheduled hash' do
        expect(instance.scheduled_jobs.keys).to eq([job_name])
      end

      it 'stores the next time execution correctly' do
        expect(next_time_execution).to be
      end
    end

    context 'in schedule' do
      let(:config) { ScheduleFaker.in_schedule }

      it 'adds the job to rufus scheduler' do
        expect(instance.rufus_scheduler.jobs.size).to be(1)
      end

      it 'puts the job inside the scheduled hash' do
        expect(instance.scheduled_jobs.keys).to eq([job_name])
      end

      it 'stores the next time execution correctly' do
        expect(next_time_execution).to be
      end
    end

    context 'interval schedule' do
      let(:config) { ScheduleFaker.interval_schedule }

      it 'adds the job to rufus scheduler' do
        expect(instance.rufus_scheduler.jobs.size).to be(1)
      end

      it 'puts the job inside the scheduled hash' do
        expect(instance.scheduled_jobs.keys).to eq([job_name])
      end

      it 'stores the next time execution correctly' do
        expect(next_time_execution).to be
      end
    end
  end

  describe '#idempotent_job_enqueue' do
    subject { instance.idempotent_job_enqueue(job_name, time, config) }

    let(:config) { JobConfigurationsFaker.some_worker }
    let(:job_name) { 'some-worker' }
    let(:pushed_job_key) { SidekiqScheduler::RedisManager.pushed_job_key(job_name) }
    let(:time) { Time.now }

    before { SidekiqScheduler::Store.del(pushed_job_key) }

    it 'enqueues a job' do
      expect { subject }.to change { Sidekiq::Queues[config['queue']].size }.by(1)
    end

    it 'registers the enqueued job' do
      expect { subject }
        .to change { SidekiqScheduler::Store.zrange(pushed_job_key, 0, -1).last == time.to_i.to_s }
        .from(false).to(true)
    end

    context 'when elder enqueued jobs' do
      let(:some_time_ago) { time - SidekiqScheduler::RedisManager::REGISTERED_JOBS_THRESHOLD_IN_SECONDS }
      let(:near_time_ago) { time - SidekiqScheduler::RedisManager::REGISTERED_JOBS_THRESHOLD_IN_SECONDS / 2 }

      before do
        Timecop.freeze(some_time_ago) do
          SidekiqScheduler::RedisManager.register_job_instance(job_name, some_time_ago)
        end

        Timecop.freeze(near_time_ago) do
          SidekiqScheduler::RedisManager.register_job_instance(job_name, near_time_ago)
        end
      end

      it 'deregisters elder enqueued jobs' do
        expect { subject }
          .to change { SidekiqScheduler::Store.zrange(pushed_job_key, 0, -1).first == some_time_ago.to_i.to_s }
          .from(true).to(false)
      end
    end

    context 'when the job has been previously enqueued' do
      it 'is not enqueued again' do
        instance.idempotent_job_enqueue(job_name, time, config)

        expect { subject }.to_not change { Sidekiq::Queues[config['queue']].size }
      end
    end

    context 'when it was enqueued for a different time' do
      before { instance.idempotent_job_enqueue(job_name, time - 1, config) }

      it 'is enqueued again' do
        expect { subject }.to change { Sidekiq::Queues[config['queue']].size }.by(1)
      end
    end
  end

  describe '#job_enabled?' do
    subject { instance.job_enabled?(job_name) }

    let(:scheduler_options) do
      {
        scheduler: {
          enabled: false,
          dynamic: true,
          dynamic_every: '5s',
          listened_queues_only: false
        }
      }
    end
    let(:job_name) { 'job_name' }
    let(:job_schedule) { { job_name => job_config } }

    before do
      Sidekiq.schedule = job_schedule
      instance.load_schedule!
    end

    context 'when the job have no schedule state' do
      context 'when the enabled base config is not set' do
        let(:job_config) do
          {
            'cron' => '* * * * *',
            'class' => 'SomeIvarJob',
            'args' => '/tmp'
          }
        end

        it 'returns true by default' do
          expect(subject).to be_truthy
        end
      end

      context 'when the enabled base config is set' do
        let(:job_config) do
          {
            'cron' => '* * * * *',
            'class' => 'SomeIvarJob',
            'args' => '/tmp',
            'enabled' => true
          }
        end

        it { is_expected.to be_truthy }
      end
    end

    context 'when the job has schedule state' do
      let(:state) { { 'enabled' => enabled } }

      before { SidekiqScheduler::RedisManager.set_job_state(job_name, state) }

      context 'when the enabled base config is not set' do
        let(:enabled) { false }
        let(:job_config) do
          {
            'cron' => '* * * * *',
            'class' => 'SomeIvarJob',
            'args' => '/tmp'
          }
        end

        it 'returns the state value' do
          expect(subject).to eq(enabled)
        end
      end

      context 'when the enabled base config is set' do
        let(:enabled) { true }
        let(:job_config) do
          {
            'cron' => '* * * * *',
            'class' => 'SomeIvarJob',
            'args' => '/tmp',
            'enabled' => false
          }
        end

        it 'returns the state value' do
          expect(subject).to eq(enabled)
        end
      end
    end
  end

  describe '#toggle_job_enabled' do
    subject { instance.toggle_job_enabled(job_name) }

    let(:scheduler_options) do
      {
        scheduler: {
          enabled: false,
          dynamic: true,
          dynamic_every: '5s',
          listened_queues_only: false
        }
      }
    end
    let(:job_name) { 'job_name' }
    let(:job_schedule) { { job_name => job_config } }

    before do
      Sidekiq.schedule = job_schedule
      instance.load_schedule!
    end

    context 'when the job has schedule state' do
      let(:state) { { 'enabled' => false } }
      let(:job_config) do
        {
          'cron' => '* * * * *',
          'class' => 'SomeIvarJob',
          'args' => '/tmp'
        }
      end

      before { SidekiqScheduler::RedisManager.set_job_state(job_name, state) }

      it 'toggles the value' do
        expect { subject }.to change { instance.job_enabled?(job_name) }
          .from(false).to(true)
      end
    end

    context 'when the job have no schedule state' do
      let(:job_config) do
        {
          'cron' => '* * * * *',
          'class' => 'SomeIvarJob',
          'args' => '/tmp',
          'enabled' => false
        }
      end

      it 'saves as state the toggled base config' do
        expect { subject }.to change { instance.job_enabled?(job_name) }
          .from(false).to(true)
      end
    end
  end

  describe '#update_schedule' do
    subject { instance.update_schedule }

    let(:scheduler_options) do
      {
        scheduler: {
          enabled: true,
          dynamic: true,
          dynamic_every: '5s',
          listened_queues_only: false
        }
      }
    end

    before do
      Sidekiq.set_schedule('old_job', ScheduleFaker.cron_schedule)
      instance.load_schedule!
    end

    context 'when a new job is added' do
      before { Sidekiq.set_schedule('new_job', ScheduleFaker.cron_schedule) }

      it 'increases the scheduled jobs size' do
        expect { subject }.to change { instance.scheduled_jobs.keys.size }.by(1)
      end

      it 'adds the new job to the scheduled hash' do
        subject
        expect(instance.scheduled_jobs.keys).to include('new_job')
      end

      it 'adds the new job to the schedule' do
        subject
        expect(Sidekiq.schedule.keys).to include('new_job')
      end
    end

    context 'when a job is removed' do
      before { Sidekiq.remove_schedule('old_job') }

      it 'decreases the scheduled jobs count' do
        expect { subject }.to change { instance.scheduled_jobs.keys.size }.by(-1)
      end

      it 'removes the job from the scheduled hash' do
        subject
        expect(instance.scheduled_jobs.keys).to_not include('old_job')
      end

      it 'removes the job from the schedule' do
        subject
        expect(Sidekiq.schedule.keys).to_not include('old_job')
      end
    end

    context 'when a job is updated' do
      let(:new_args) do
        {
          'cron' => '1 * * * *',
          'class' => 'SystemNotifierWorker',
          'args' => '',
          'queue' => 'some_queue'
        }
      end
      let(:job) { Sidekiq.schedule['old_job'] }
      let(:rufus_job) { instance.scheduled_jobs['old_job'] }

      before { Sidekiq.set_schedule('old_job', ScheduleFaker.cron_schedule(new_args)) }

      it 'keeps the job in the scheduled hash' do
        subject
        expect(instance.scheduled_jobs.keys).to include('old_job')
      end

      it 'keeps the job in the schedule' do
        subject
        expect(Sidekiq.schedule.keys).to include('old_job')
      end

      it 'updates the job with the new args scheduled jobs' do
        subject
        expect(job).to eq(new_args)
      end

      it 'updates the rufus job with the new args' do
        subject
        expect(rufus_job.original).to eq(new_args['cron'])
      end
    end

    context 'when the job is updated' do
      before { Sidekiq.set_schedule('old_job', ScheduleFaker.cron_schedule('cron' => '1 * * * *')) }

      it 'does not removes the job from the scheduled hash' do
        expect { subject }.to_not change { instance.scheduled_jobs.keys.size }
      end

      it 'resets the instance variable current_change_score' do
        expect { subject }.to change { instance.instance_variable_get(:@current_changed_score) }.to be_a(Float)
      end
    end
  end
end
