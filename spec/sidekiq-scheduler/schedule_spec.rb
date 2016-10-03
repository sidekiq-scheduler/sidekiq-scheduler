describe SidekiqScheduler::Schedule do
  before { Sidekiq.redis(&:flushall) }

  def build_cron_hash
    {
      'cron'  => '* * * * *',
      'class' => 'SomeIvarJob',
      'args'  => '/tmp/75'
    }
  end

  def only_cron_and_args
    -> (key, _) { %w(cron args).include?(key) }
  end

  def job_from_redis(job_id)
    if job = job_from_redis_without_decoding(job_id)
      MultiJson.decode(job)
    end
  end

  def changed_job?(job_id)
    Sidekiq.redis { |redis| redis.sismember(:schedules_changed, job_id) }
  end

  def job_from_redis_without_decoding(job_id)
    Sidekiq.redis { |redis| redis.hget(:schedules, job_id) }
  end

  let(:cron_hash)    { ScheduleFaker.default_options('args' => 'some_arg') }
  let(:job_id)       { 'super_job' }
  let(:job_class_id) { cron_hash['class'] }

  describe '.schedule=' do
    before { Sidekiq::Scheduler.dynamic = true }

    it 'sets the schedule on redis' do
      Sidekiq.schedule = {job_id => cron_hash}

      expect(cron_hash).to eq(job_from_redis(job_id))
    end

    it 'uses job name as \'class\' argument if it\'s missing' do
      Sidekiq.schedule = {job_class_id => cron_hash.select(&only_cron_and_args)}

      job = Sidekiq.schedule[job_class_id]

      expect(cron_hash).to eq(job_from_redis(job_class_id))
      expect(job['class']).to eq(job_class_id)
    end

    context 'when job key is a symbol' do
      let(:job_id) { :super_job }

      context 'when schedule is set twice' do
        it 'sets the schedule on redis' do
          2.times { Sidekiq.schedule = { job_id => cron_hash } }

          expect(cron_hash).to eq(job_from_redis(job_id))
        end
      end
    end

    context 'when Symbol keys' do
      let(:symbolized_schedule) do
        {
          worker: { class: 'SomeWorker', every: '20s', queue: 'low', description: 'symbols' }
        }
      end

      let(:stringified_schedule) do
        {
          'worker' => {
            'class' => 'SomeWorker', 'every' => '20s', 'queue' => 'low', 'description' => 'symbols'
          }
        }
      end

      it 'converts them into Strings' do
        Sidekiq.schedule = symbolized_schedule

        expect(Sidekiq.schedule).to eq(stringified_schedule)
      end
    end
  end

  describe '.set_schedule' do
    it 'set_schedule can set an individual schedule' do
      Sidekiq.set_schedule(job_id, cron_hash)

      expect(cron_hash).to eq(job_from_redis(job_id))
      expect(changed_job?(job_id)).to be_truthy
    end
  end

  describe '.get_schedule' do
    it 'returns a schedule' do
      Sidekiq.set_schedule(job_id, cron_hash)

      schedule = Sidekiq.get_schedule(job_id)

      expect(schedule).to eq(job_from_redis(job_id))
    end
  end

  describe '.remove_schedule' do
    it 'removes a schedule from redis' do
      Sidekiq.set_schedule(job_id, cron_hash)

      Sidekiq.remove_schedule(job_id)

      expect(job_from_redis_without_decoding(job_id)).to be_nil
      expect(changed_job?(job_id)).to be_truthy
    end
  end

end
