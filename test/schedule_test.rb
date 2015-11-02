require 'test_helper'

class ScheduleTest < Minitest::Test

  describe 'SidekiqScheduler::Schedule' do

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
      MultiJson.decode(job_from_redis_without_decoding(job_id))
    end

    def job_from_redis_without_decoding(job_id)
      Sidekiq.redis { |redis|
        redis.hget(:schedules, job_id)
      }
    end

    let(:cron_hash)    { build_cron_hash }
    let(:job_id)       { 'my_ivar_job' }
    let(:job_class_id) { 'SomeIvarJob' }

    it 'schedule= sets the schedule' do
      Sidekiq::Scheduler.dynamic = true

      Sidekiq.schedule = {job_id => cron_hash}

      assert_equal(cron_hash, job_from_redis(job_id))
    end

    it "schedule= uses job name as 'class' argument if it's missing" do
      Sidekiq::Scheduler.dynamic = true

      Sidekiq.schedule = {job_class_id => cron_hash.select(&only_cron_and_args)}

      assert_equal(cron_hash, job_from_redis(job_class_id))
      assert_equal(job_class_id, Sidekiq.schedule[job_class_id]['class'])
    end

    it 'schedule= does not mutate argument' do
      schedule = {job_class_id => cron_hash.select(&only_cron_and_args)}

      Sidekiq.schedule = schedule

      assert !schedule[job_class_id].key?('class')
    end

    it 'set_schedule can set an individual schedule' do
      Sidekiq.set_schedule(job_id, cron_hash)

      assert_equal(cron_hash, job_from_redis(job_id))
      assert Sidekiq.redis { |r| r.sismember(:schedules_changed, job_id) }
    end

    it 'get_schedule returns a schedule' do
      Sidekiq.redis { |r| r.hset(:schedules, job_id, MultiJson.encode(cron_hash)) }

      assert_equal(cron_hash, Sidekiq.get_schedule(job_id))
    end

    it 'remove_schedule removes a schedule' do
      Sidekiq.redis { |r| r.hset(:schedules, job_id, MultiJson.encode(cron_hash)) }

      Sidekiq.remove_schedule(job_id)

      assert_equal nil, job_from_redis_without_decoding(job_id)
      assert Sidekiq.redis{ |r| r.sismember(:schedules_changed, job_id) }
    end
  end
end
