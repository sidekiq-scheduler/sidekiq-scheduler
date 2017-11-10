describe SidekiqScheduler::Scheduler do

  before do
    described_class.enabled = true
    described_class.dynamic = false
    described_class.dynamic_every = '5s'
    described_class.listened_queues_only = false
    Sidekiq.redis(&:flushall)
    Sidekiq.options[:queues] = Sidekiq::DEFAULTS[:queues]
    described_class.clear_schedule!
    described_class.send(:class_variable_set, :@@scheduled_jobs, {})
    Sidekiq::Worker.clear_all
  end


  describe '.load_schedule' do
    context 'when the enabled option is false' do
      let(:job_schedule) do
        {
          'some_ivar_job' => {
            'cron' => '* * * * *',
            'class' => 'SomeIvarJob',
            'args' => '/tmp'
          }
        }
      end

      before do
        described_class.enabled = false
        Sidekiq.schedule = job_schedule
        described_class.load_schedule!
      end

      it 'does not increase the jobs ammount' do
        expect(described_class.rufus_scheduler.jobs.size).to equal(0)
      end

      it 'does not add the job to the scheduled jobs' do
        expect(described_class.scheduled_jobs).not_to include('some_ivar_job')
      end
    end
  end

  describe '.enqueue_job' do
    let(:schedule_time) { Time.now }
    let(:args) { '/tmp' }
    let(:scheduler_config) do
      { 'class' => 'SomeWorker', 'queue' => 'high', 'args'  => args, 'cron' => '* * * * *' }
    end

    # The job should be loaded, since a missing rails_env means ALL envs.
    before { ENV['RAILS_ENV'] = 'production' }

    context 'when it is a sidekiq worker' do
      it 'prepares the parameters' do
        expect(Sidekiq::Client).to receive(:push).with({
          'class' => SomeWorker,
          'queue' => 'high',
          'args' => ['/tmp']
        })

        described_class.enqueue_job(scheduler_config, schedule_time)
      end
    end

    context 'when it is an activejob worker' do
      before do
        scheduler_config['class'] = EmailSender
      end

      specify 'enqueues the job as active job' do
        expect(EmailSender).to receive(:new).with(
          '/tmp',
        ).and_return(double(:job).as_null_object)

        described_class.enqueue_job(scheduler_config, schedule_time)
      end

      specify 'enqueue to the configured queue' do
        expect_any_instance_of(EmailSender).to receive(:enqueue).with({
          queue: 'high'
        })

        described_class.enqueue_job(scheduler_config, schedule_time)
      end

      context 'when queue is not configured' do
        before do
          scheduler_config.delete('queue')
        end

        specify 'does not include :queue option' do
          expect_any_instance_of(EmailSender).to receive(:enqueue).with({})

          described_class.enqueue_job(scheduler_config, schedule_time)
        end
      end
    end

    context 'when worker class does not exist' do
      before do
        scheduler_config['class'] = 'NonExistentWorker'
      end

      it 'prepares the parameters' do
        expect(Sidekiq::Client).to receive(:push).with({
          'class' => 'NonExistentWorker',
          'queue' => 'high',
          'args' => ['/tmp']
        })

        described_class.enqueue_job(scheduler_config, schedule_time)
      end
    end

    context 'when job is configured to receive metadata' do
      before do
        scheduler_config['include_metadata'] = true
      end

      context 'when called without a time argument' do
        specify 'uses the current time' do
          Timecop.freeze(schedule_time) do
            expect(Sidekiq::Client).to receive(:push).with({
              'class' => SomeWorker,
              'queue' => 'high',
              'args' => ['/tmp', {scheduled_at: schedule_time.to_f}]
            })

            described_class.enqueue_job(scheduler_config)
          end
        end
      end

      context 'when arguments are already expanded' do
        it 'pushes the job with the metadata as the last argument' do
          Timecop.freeze(schedule_time) do
            expect(Sidekiq::Client).to receive(:push).with({
              'class' => SomeWorker,
              'queue' => 'high',
              'args' => ['/tmp', {scheduled_at: schedule_time.to_f}]
            })

            described_class.enqueue_job(scheduler_config, schedule_time)
          end
        end
      end

      context 'when it is an active job worker' do
        before do
          scheduler_config['class'] = EmailSender
        end

        specify 'enqueues the job as active job' do
          expect(EmailSender).to receive(:new).with(
            '/tmp',
            { scheduled_at: schedule_time.to_f }
          ).and_return(double(:job).as_null_object)

          described_class.enqueue_job(scheduler_config, schedule_time)
        end

        specify 'enqueue to the configured queue' do
          expect_any_instance_of(EmailSender).to receive(:enqueue).with({
            queue: 'high'
          })

          described_class.enqueue_job(scheduler_config, schedule_time)
        end
      end

      context 'when arguments contain a hash' do
        let(:args) { { 'dir' => '/tmp' } }

        it 'pushes the job with the metadata as the last argument' do
          Timecop.freeze(schedule_time) do
            expect(Sidekiq::Client).to receive(:push).with({
              'class' => SomeWorker,
              'queue' => 'high',
              'args' => [{dir: '/tmp'}, {scheduled_at: schedule_time.to_f}]
            })

            described_class.enqueue_job(scheduler_config, schedule_time)
          end
        end
      end

      context 'when arguments are empty' do
        before do
          scheduler_config.delete('args')
        end

        it 'pushes the job with the metadata as the only argument' do
          Timecop.freeze(schedule_time) do
            expect(Sidekiq::Client).to receive(:push).with({
              'class' => SomeWorker,
              'queue' => 'high',
              'args' => [{scheduled_at: schedule_time.to_f}]
            })

            described_class.enqueue_job(scheduler_config, schedule_time)
          end
        end
      end

    end
  end

  describe '.rufus_scheduler' do
    let(:job) { double('job', tags: ['tag'], next_time: 'next_time') }

    it 'can pass options to the Rufus scheduler instance' do
      options = { :lockfile => '/tmp/rufus_lock' }

      expect(Rufus::Scheduler).to receive(:new).with(options)

      described_class.rufus_scheduler_options = options
      described_class.clear_schedule!
    end

    it 'sets a trigger to update the next execution time for the jobs' do
      expect(described_class).to receive(:update_job_next_time)
        .with(job.tags[0], job.next_time)

      described_class.rufus_scheduler.on_post_trigger(job, 'triggered_time')
    end

    it 'sets a trigger to update the last execution time for the jobs' do
      expect(described_class).to receive(:update_job_last_time)
        .with(job.tags[0], 'triggered_time')

      described_class.rufus_scheduler.on_post_trigger(job, 'triggered_time')
    end
  end

  describe '.load_schedule!' do
    it 'should correctly load the job into rufus_scheduler' do
      expect {
        Sidekiq.schedule = {
          'some_ivar_job' => {
            'cron'  => '* * * * *',
            'class' => 'SomeWorker',
            'args'  => '/tmp'
          }
        }

        described_class.load_schedule!
      }.to change { described_class.rufus_scheduler.jobs.size }.from(0).to(1)

      expect(described_class.scheduled_jobs).to include('some_ivar_job')
    end

    context 'when job has a configured queue' do
      before do
        Sidekiq.schedule = {
          'some_ivar_job' => {
            'cron'  => '* * * * *',
            'class' => 'ReportWorker',
            'queue' => 'reporting'
          }
        }
      end

      context 'when listened_queues_only flag is active' do
        before { described_class.listened_queues_only = true }

        context 'when default sidekiq queues' do
          before do
            Sidekiq.options[:queues] = Sidekiq::DEFAULTS[:queues]
          end

          it 'loads the job into the scheduler' do
            described_class.load_schedule!

            expect(described_class.scheduled_jobs).to include('some_ivar_job')
          end
        end

        context 'when sidekiq queues match job\'s one' do
          before do
            Sidekiq.options[:queues] = ['reporting']
          end

          it 'loads the job into the scheduler' do
            described_class.load_schedule!

            expect(described_class.scheduled_jobs).to include('some_ivar_job')
          end
        end

        context 'when stringified sidekiq queues match symbolized job\'s one' do
          before do
            Sidekiq.options[:queues] = ['reporting']
            Sidekiq.schedule['some_ivar_job']['queue'] = :reporting
          end

          it 'loads the job into the scheduler' do
            described_class.load_schedule!

            expect(described_class.scheduled_jobs).to include('some_ivar_job')
          end
        end

        context 'when symbolized sidekiq queues match stringified job\'s one' do
          before do
            Sidekiq.options[:queues] = ['reporting']
            Sidekiq.schedule['some_ivar_job']['queue'] = :reporting
          end

          it 'loads the job into the scheduler' do
            described_class.load_schedule!

            expect(described_class.scheduled_jobs).to include('some_ivar_job')
          end
        end

        context 'when sidekiq queues does not match job\'s one' do
          before do
            Sidekiq.options[:queues] = ['mailing']
          end

          it 'does not load the job into the scheduler' do
            described_class.load_schedule!

            expect(described_class.scheduled_jobs).to_not include('some_ivar_job')
          end
        end
      end

      context 'when listened_queues_only flag is inactive' do
        before { described_class.listened_queues_only = false }

        context 'when sidekiq queues does not match job\'s one' do
          before do
            Sidekiq.options[:queues] = ['mailing']
          end

          it 'loads the job into the scheduler' do
            described_class.load_schedule!

            expect(described_class.scheduled_jobs).to include('some_ivar_job')
          end
        end
      end
    end

    context 'when job has no configured queue' do
      before do
        Sidekiq.schedule = {
          'some_ivar_job' => {
            'cron'  => '* * * * *',
            'class' => 'ReportWorker'
          }
        }
      end

      context 'when listened_queues_only flag is active' do
        before { described_class.listened_queues_only = true }

        context 'when configured sidekiq queues' do
          before do
            Sidekiq.options[:queues] = ['mailing']
          end

          it 'does not load the job into the scheduler' do
            described_class.load_schedule!

            expect(described_class.scheduled_jobs).to_not include('some_ivar_job')
          end
        end

        context 'when default sidekiq queues' do
          before do
            Sidekiq.options[:queues] = Sidekiq::DEFAULTS[:queues]
          end

          it 'loads the job into the scheduler' do
            described_class.load_schedule!

            expect(described_class.scheduled_jobs).to include('some_ivar_job')
          end
        end
      end

      context 'when listened_queues_only flag is false' do
        before { described_class.listened_queues_only = false }

        context 'when configured sidekiq queues' do
          before do
            Sidekiq.options[:queues] = ['mailing']
          end

          it 'loads the job into the scheduler' do
            described_class.load_schedule!

            expect(described_class.scheduled_jobs).to include('some_ivar_job')
          end
        end
      end
    end
  end

  describe '.reload_schedule!' do
    before { described_class.dynamic = true }

    it 'should include new values' do
      described_class.load_schedule!

      expect {
        Sidekiq.redis  { |r| r.del(:schedules) }
        Sidekiq.redis do |r|
          r.hset(:schedules, 'some_ivar_job2',
            JSON.generate({
              'cron' => '* * * * *',
              'class' => 'SomeWorker',
              'args' => '/tmp/2'
            })
          )
        end

        described_class.reload_schedule!
      }.to change { described_class.scheduled_jobs.include?('some_ivar_job2') }.to(true)
    end

    it 'should remove old values that are not reincluded' do
      Sidekiq.schedule = {
        'some_ivar_job' => {
          'cron' => '* * * * *',
          'class' => 'SomeWorker',
          'args' => '/tmp'
        }
      }

      described_class.load_schedule!

      expect {
        Sidekiq.redis  { |r| r.del(:schedules) }

        described_class.reload_schedule!
      }.to change { described_class.scheduled_jobs.include?('some_ivar_job') }.to(false)
    end

    it 'reloads the schedule from redis after 5 seconds when dynamic' do
      Sidekiq.set_schedule('some_job', ScheduleFaker.cron_schedule({'args' => '/tmp'}))

      described_class.load_schedule!

      expect {
        Sidekiq.set_schedule('other_job', ScheduleFaker.cron_schedule({'args' => 'sample'}))
        Timecop.travel(7 * 60)
        sleep 0.5
      }.to change { described_class.scheduled_jobs.include?('other_job') }.to(true)
    end

    context 'when dynamic_every is set' do
      context 'to 5m' do
        before { described_class.dynamic_every = '5m' }

        it 'does not reload the schedule from redis after 2 minutes' do
          Sidekiq.set_schedule('some_job', ScheduleFaker.cron_schedule({'args' => '/tmp'}))

          described_class.load_schedule!

          expect {
            Sidekiq.set_schedule('other_job', ScheduleFaker.cron_schedule({'args' => 'sample'}))
            Timecop.travel(2 * 60)
            sleep 0.5
          }.to_not change { described_class.scheduled_jobs.include?('other_job') }
        end

        it 'reloads the schedule from redis after 10 minutes' do
          Sidekiq.set_schedule('some_job', ScheduleFaker.cron_schedule({'args' => '/tmp'}))

          described_class.load_schedule!

          expect {
            Sidekiq.set_schedule('other_job', ScheduleFaker.cron_schedule({'args' => 'sample'}))
            Timecop.travel(10 * 60)
            sleep 0.5
          }.to change { described_class.scheduled_jobs.include?('other_job') }.to(true)
        end
      end
    end
  end

  describe '.load_schedule_job' do

    let(:job_name) { 'some_job' }
    let(:next_time_execution) do
      Sidekiq.redis { |r| r.hexists(SidekiqScheduler::RedisManager.next_times_key, job_name) }
    end

    context 'without a timing option' do
      before do
        described_class.load_schedule_job(job_name, ScheduleFaker.invalid_schedule)
      end

      it 'does not put the job inside the scheduled hash' do
        expect(described_class.scheduled_jobs.keys).to be_empty
      end

      it 'does not add the job to rufus scheduler' do
        expect(described_class.rufus_scheduler.jobs.size).to be(0)
      end

      it 'does not store the next time execution correctly' do
        expect(next_time_execution).not_to be
      end
    end

    context 'cron schedule' do
      context 'without options' do
        before { described_class.load_schedule_job(job_name, ScheduleFaker.cron_schedule) }

        it 'adds the job to rufus scheduler' do
          expect(described_class.rufus_scheduler.jobs.size).to be(1)
        end

        it 'puts the job inside the scheduled hash' do
          expect(described_class.scheduled_jobs.keys).to eq([job_name])
        end

        it 'stores the next time execution correctly' do
          expect(next_time_execution).to be
        end

        it 'sets a tag for the job with the name' do
          expect(described_class.scheduled_jobs[job_name].tags).to eq([job_name])
        end
      end

      context 'with options' do
        context 'when the options are valid' do
          before do
            described_class.load_schedule_job(job_name,
              ScheduleFaker.cron_schedule('allow_overlapping' => 'true'))
          end

          it 'adds the job to rufus scheduler' do
            expect(described_class.rufus_scheduler.jobs.size).to be(1)
          end

          it 'puts the job inside the scheduled hash' do
            expect(described_class.scheduled_jobs.keys).to eq([job_name])
          end

          it 'sets the default options' do
            expect(described_class.scheduled_jobs[job_name].params.keys).
              to include(:allow_overlapping)
          end

          it 'stores the next time execution correctly' do
            expect(next_time_execution).to be
          end
        end

        context 'when the cron is empty' do
          before do
            described_class.load_schedule_job(job_name, ScheduleFaker.cron_schedule('cron' => ''))
          end

          it 'does not put the job inside the scheduled hash' do
            expect(described_class.scheduled_jobs.keys).to be_empty
          end

          it 'does not add the job to rufus scheduler' do
            expect(described_class.rufus_scheduler.jobs.size).to be(0)
          end

          it 'does not store the next time execution correctly' do
            expect(next_time_execution).not_to be
          end
        end
      end
    end

    context 'every schedule' do
      context 'without options' do
        before do
          described_class.load_schedule_job(job_name, ScheduleFaker.every_schedule)
        end

        it 'adds the job to rufus scheduler' do
          expect(described_class.rufus_scheduler.jobs.size).to be(1)
        end

        it 'puts the job inside the scheduled hash' do
          expect(described_class.scheduled_jobs.keys).to eq([job_name])
        end

        it 'stores the next time execution correctly' do
          expect(next_time_execution).to be
        end
      end

      context 'with options' do
        before do
          described_class.load_schedule_job(job_name,
            ScheduleFaker.every_schedule({'first_in' => '60s'}))
        end

        it 'adds the job to rufus scheduler' do
          expect(described_class.rufus_scheduler.jobs.size).to be(1)
        end

        it 'puts the job inside the scheduled hash' do
          expect(described_class.scheduled_jobs.keys).to eq([job_name])
        end

        it 'sets the default options' do
          expect(described_class.scheduled_jobs[job_name].params.keys).
            to include(:first_in)
        end

        it 'stores the next time execution correctly' do
          expect(next_time_execution).to be
        end
      end
    end

    context 'at schedule' do
      before { described_class.load_schedule_job(job_name, ScheduleFaker.at_schedule) }

      it 'adds the job to rufus scheduler' do
        expect(described_class.rufus_scheduler.jobs.size).to be(1)
      end

      it 'puts the job inside the scheduled hash' do
        expect(described_class.scheduled_jobs.keys).to eq([job_name])
      end

      it 'stores the next time execution correctly' do
        expect(next_time_execution).to be
      end
    end

    context 'in schedule' do
      before { described_class.load_schedule_job(job_name, ScheduleFaker.in_schedule) }

      it 'adds the job to rufus scheduler' do
        expect(described_class.rufus_scheduler.jobs.size).to be(1)
      end

      it 'puts the job inside the scheduled hash' do
        expect(described_class.scheduled_jobs.keys).to eq([job_name])
      end

      it 'stores the next time execution correctly' do
        expect(next_time_execution).to be
      end
    end

    context 'interval schedule' do
      before { described_class.load_schedule_job(job_name, ScheduleFaker.interval_schedule) }

      it 'adds the job to rufus scheduler' do
        expect(described_class.rufus_scheduler.jobs.size).to be(1)
      end

      it 'puts the job inside the scheduled hash' do
        expect(described_class.scheduled_jobs.keys).to eq([job_name])
      end

      it 'stores the next time execution correctly' do
        expect(next_time_execution).to be
      end
    end
  end

  describe '.idempotent_job_enqueue' do
    def enqueued_jobs_registry
      Sidekiq.redis { |r| r.zrange(pushed_job_key, 0, -1) }
    end

    let(:config) { JobConfigurationsFaker.some_worker }

    let(:job_name) { 'some-worker' }

    let(:pushed_job_key) { SidekiqScheduler::RedisManager.pushed_job_key(job_name) }

    before do
      Sidekiq.redis { |r| r.del(pushed_job_key) }
    end

    let(:time) { Time.now }

    it 'enqueues a job' do
      expect {
        described_class.idempotent_job_enqueue(job_name, time, config)
      }.to change { Sidekiq::Queues[config['queue']].size }.by(1)
    end

    it 'registers the enqueued job' do
      expect {
        described_class.idempotent_job_enqueue(job_name, time, config)
      }.to change { enqueued_jobs_registry.last == time.to_i.to_s }.from(false).to(true)
    end

    context 'when elder enqueued jobs' do
      let(:some_time_ago) { time - SidekiqScheduler::RedisManager::REGISTERED_JOBS_THRESHOLD_IN_SECONDS }

      let(:near_time_ago) { time - SidekiqScheduler::RedisManager::REGISTERED_JOBS_THRESHOLD_IN_SECONDS  / 2 }

      before  do
        Timecop.freeze(some_time_ago) do
          described_class.register_job_instance(job_name, some_time_ago)
        end

        Timecop.freeze(near_time_ago) do
          described_class.register_job_instance(job_name, near_time_ago)
        end
      end

      it 'deregisters elder enqueued jobs' do
        expect {
          described_class.idempotent_job_enqueue(job_name, time, config)
        }.to change { enqueued_jobs_registry.first == some_time_ago.to_i.to_s }.from(true).to(false)
      end
    end

    context 'when the job has been previously enqueued' do
      before { described_class.idempotent_job_enqueue(job_name, time, config) }

      it 'is not enqueued again' do
        expect {
          described_class.idempotent_job_enqueue(job_name, time, config)
        }.to_not change { Sidekiq::Queues[config['queue']].size }
      end
    end

    context 'when it was enqueued for a different Time' do
      before { described_class.idempotent_job_enqueue(job_name, time - 1, config) }

      it 'is enqueued again' do
        expect {
          described_class.idempotent_job_enqueue(job_name, time, config)
        }.to change { Sidekiq::Queues[config['queue']].size }.by(1)
      end
    end
  end

  describe '.update_schedule' do
    before do
      described_class.dynamic = true
      Sidekiq.set_schedule('old_job', ScheduleFaker.cron_schedule)
      described_class.load_schedule!
    end

    context 'when a new job is added' do
      before { Sidekiq.set_schedule('new_job', ScheduleFaker.cron_schedule) }

      it 'increases the scheduled jobs size' do
        expect { described_class.update_schedule }
          .to change { described_class.scheduled_jobs.keys.size }.by(1)
      end

      it 'adds the new job to the scheduled hash' do
        described_class.update_schedule
        expect(described_class.scheduled_jobs.keys).to include('new_job')
      end

      it 'adds the new job to the schedule' do
        described_class.update_schedule
        expect(Sidekiq.schedule.keys).to include('new_job')
      end
    end

    context 'when a job is removed' do
      before do
        Sidekiq.remove_schedule('old_job')
      end

      it 'decreases the scheduled jobs count' do
        expect {
          described_class.update_schedule
        }.to change { described_class.scheduled_jobs.keys.size }.by(-1)
      end

      it 'removes the job from the scheduled hash' do
        described_class.update_schedule
        expect(described_class.scheduled_jobs.keys).to_not include('old_job')
      end

      it 'removes the job from the schedule' do
        described_class.update_schedule
        expect(Sidekiq.schedule.keys).to_not include('old_job')
      end
    end

    context 'when a job is updated' do
      let(:new_args) do
        {
          'cron'  => '1 * * * *',
          'class' => 'SystemNotifierWorker',
          'args'  => '',
          'queue' => 'some_queue'
        }
      end
      let(:job) { Sidekiq.schedule['old_job'] }
      let(:rufus_job) { described_class.scheduled_jobs['old_job'] }

      before do
        Sidekiq.set_schedule('old_job', ScheduleFaker.cron_schedule(new_args))
        described_class.update_schedule
      end

      it 'keeps the job in the scheduled hash' do
        expect(described_class.scheduled_jobs.keys).to include('old_job')
      end

      it 'keeps the job in the schedule' do
        expect(Sidekiq.schedule.keys).to include('old_job')
      end

      it 'updates the job with the new args scheduled jobs' do
        expect(job).to eq(new_args)
      end

      it 'updates the rufus job with the new args' do
        expect(rufus_job.original).to eq(new_args['cron'])
      end
    end

    context 'when the job is updated' do
      before { Sidekiq.set_schedule('old_job', ScheduleFaker.cron_schedule('cron' => '1 * * * *')) }


      it 'does not removes the job from the scheduled hash' do
        expect {
          described_class.update_schedule
        }.to_not change { described_class.scheduled_jobs.keys.size }
      end

      it 'resets the instance variable current_change_score' do
        expect { described_class.update_schedule }
          .to change{ described_class.instance_variable_get(:@current_changed_score) }.to be_a Float
      end
    end
  end

  describe '.enqueue_with_active_job' do
    it 'enque an object with no args' do
      expect(EmailSender).to receive(:new).with(no_args).twice.and_call_original

      described_class.enqueue_with_active_job({
        'class' => EmailSender,
        'args'  => []
      })
    end

    describe 'enqueue an object with args' do
      it 'should be correctly enqueued' do
        expect(AddressUpdater).to receive(:new).with(100).
          and_call_original
        expect(AddressUpdater).to receive(:new).with(no_args).
          and_call_original

        described_class.enqueue_with_active_job({
          'class' => AddressUpdater,
          'args'  => [100]
        })
      end
    end
  end

  describe '.enqueue_with_sidekiq' do
    let(:config) { JobConfigurationsFaker.some_worker }

    it 'enqueues a job into a sidekiq queue' do
      expect {
        described_class.enqueue_with_sidekiq(config)
      }.to change { Sidekiq::Queues[config['queue']].size }.by(1)
    end

    context 'when the config have rufus related keys' do
      let(:rufus_config) { { described_class::RUFUS_METADATA_KEYS.sample => "value" } }

      it 'removes those keys' do
        expect(Sidekiq::Client).to receive(:push).with(config)
        described_class.enqueue_with_sidekiq(config.merge(rufus_config))
      end
    end
  end

  describe '.initialize_active_job' do
    describe 'when the object has no arguments' do
      it 'should be correctly initialized' do
        expect(EmailSender).to receive(:new).with(no_args).and_call_original

        object = described_class.initialize_active_job(EmailSender, [])

        expect(object).to be_instance_of(EmailSender)
      end
    end

    describe 'when the object has a hash as an argument' do
      it 'should be correctly initialized' do
        expect(::EmailSender).to receive(:new).with({testing: 'Argument'}).and_call_original

        object = described_class.initialize_active_job(EmailSender, {testing: 'Argument'})

        expect(object).to be_instance_of(EmailSender)
      end
    end

    describe 'when the object has many arguments' do
      it 'should be correctly initialized' do
        expect(EmailSender).to receive(:new).with('one', 'two').and_call_original

        object = described_class.initialize_active_job(EmailSender, ['one', 'two'])

        expect(object).to be_instance_of(EmailSender)
      end
    end
  end

  describe '.register_job_instance' do
    let(:job_name) { 'some-worker' }

    let(:pushed_job_key) { SidekiqScheduler::RedisManager.pushed_job_key(job_name) }

    let(:now) { Time.now }

    it { expect(described_class.register_job_instance(job_name, now)).to be true }

    it 'stores the job instance into Redis' do
      expect {
        described_class.register_job_instance(job_name, now)
      }.to change { Sidekiq.redis { |r| r.zcard(pushed_job_key) } }.by(1)
    end

    it 'persists a expirable key' do
      described_class.register_job_instance(job_name, now)

      Timecop.travel(SidekiqScheduler::RedisManager::REGISTERED_JOBS_THRESHOLD_IN_SECONDS) do
        expect(Sidekiq.redis { |r| r.exists(pushed_job_key) }).to be false
      end
    end

    context 'when job has been previously registered' do
      before { described_class.register_job_instance(job_name, now) }

      it { expect(described_class.register_job_instance(job_name, now)).to be false }

      context 'but with different timestamp' do
        let(:another_timestamp) { now + 1 }

        it 'is true' do
          expect(described_class.register_job_instance(job_name, another_timestamp)).to be true
        end
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

  describe '.job_enabled?' do
    let(:job_name) { 'job_name' }
    let(:job_schedule) { { job_name => job_config } }

    subject { described_class.job_enabled?(job_name) }

    before do
      described_class.enabled = false
      Sidekiq.schedule = job_schedule
      described_class.load_schedule!
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
          expect(subject).to be
        end
      end

      context 'when the enabled base config is set' do
        let(:enabled) { false }
        let(:job_config) do
          {
            'cron' => '* * * * *',
            'class' => 'SomeIvarJob',
            'args' => '/tmp',
            'enabled' => enabled
          }
        end

        it 'returns the value' do
          expect(subject).to eq(enabled)
        end
      end
    end

    context 'when the job has schedule state' do
      let(:state) { { 'enabled' => enabled } }

      before do
        Sidekiq.redis do |r|
          r.hset(SidekiqScheduler::RedisManager.schedules_state_key, job_name, JSON.generate(state))
        end
      end


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

  describe '.toggle_job_enabled' do
    let(:job_name) { 'job_name' }
    let(:job_schedule) { { job_name => job_config } }

    subject { described_class.toggle_job_enabled(job_name) }

    before do
      described_class.enabled = false
      Sidekiq.schedule = job_schedule
      described_class.load_schedule!
    end

    context 'when the job has schedule state' do
      let(:enabled) { false }
      let(:state) { { 'enabled' => enabled } }
      let(:job_config) do
        {
          'cron' => '* * * * *',
          'class' => 'SomeIvarJob',
          'args' => '/tmp'
        }
      end

      before do
        Sidekiq.redis do |r|
          r.hset(SidekiqScheduler::RedisManager.schedules_state_key, job_name, JSON.generate(state))
        end
      end

      it 'toggles the value' do
        expect { subject }.to change { described_class.job_enabled?(job_name) }
          .from(enabled).to(!enabled)
      end
    end

    context 'when the job have no schedule state' do
      let(:enabled) { false }
      let(:job_config) do
        {
          'cron' => '* * * * *',
          'class' => 'SomeIvarJob',
          'args' => '/tmp',
          'enabled' => enabled
        }
      end

      it 'saves as state the toggled base config' do
        expect { subject }.to change { described_class.job_enabled?(job_name) }
          .from(enabled).to(!enabled)
      end
    end
  end
end
