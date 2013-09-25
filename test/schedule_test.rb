require 'test_helper'

class ScheduleTest < Minitest::Test

  describe 'SidekiqScheduler::Schedule' do
    it 'schedule= sets the schedule' do
      Sidekiq::Scheduler.dynamic = true
      Sidekiq.schedule = {
          'my_ivar_job' => {
              'cron' => '* * * * *',
              'class' => 'SomeIvarJob',
              'args' => '/tmp/75'
          }
      }

      assert_equal(
          {
              'cron' => '* * * * *',
              'class' => 'SomeIvarJob',
              'args' => '/tmp/75'
          },
          MultiJson.decode(Sidekiq.redis { |r|
            r.hget(:schedules, 'my_ivar_job')
          })
      )
    end

    it "schedule= uses job name as 'class' argument if it's missing" do
      Sidekiq::Scheduler.dynamic = true
      Sidekiq.schedule = {
          'SomeIvarJob' => {
              'cron' => '* * * * *',
              'args' => '/tmp/75'
          }
      }

      assert_equal(
          {
              'cron' => '* * * * *',
              'class' => 'SomeIvarJob',
              'args' => '/tmp/75'
          },
          MultiJson.decode(Sidekiq.redis { |r| r.hget(:schedules, 'SomeIvarJob') })
      )
      assert_equal('SomeIvarJob', Sidekiq.schedule['SomeIvarJob']['class'])
    end

    it 'schedule= does not mutate argument' do
      schedule = {
          'SomeIvarJob' => {
              'cron' => '* * * * *',
              'args' => '/tmp/75'
          }
      }
      Sidekiq.schedule = schedule
      assert !schedule['SomeIvarJob'].key?('class')
    end

    it 'set_schedule can set an individual schedule' do
      Sidekiq.set_schedule(
          'some_ivar_job',
          {
              'cron' => '* * * * *',
              'class' => 'SomeIvarJob',
              'args' => '/tmp/22'
          }
      )
      assert_equal(
          {
              'cron' => '* * * * *',
              'class' => 'SomeIvarJob',
              'args' => '/tmp/22'
          },
          MultiJson.decode(Sidekiq.redis { |r| r.hget(:schedules, 'some_ivar_job') })
      )
      assert Sidekiq.redis { |r| r.sismember(:schedules_changed, 'some_ivar_job') }
    end

    it 'get_schedule returns a schedule' do
      Sidekiq.redis { |r| r.hset(
          :schedules,
          'some_ivar_job2',
          MultiJson.encode(
              {
                  'cron' => '* * * * *',
                  'class' => 'SomeIvarJob',
                  'args' => '/tmp/33'
              }
          )
      ) }
      assert_equal(
          {
              'cron' => '* * * * *',
              'class' => 'SomeIvarJob',
              'args' => '/tmp/33'
          },
          Sidekiq.get_schedule('some_ivar_job2')
      )
    end

    it 'remove_schedule removes a schedule' do
      Sidekiq.redis do |r|
        r.hset(
            :schedules,
            'some_ivar_job3',
            MultiJson.encode(
                {
                    'cron' => '* * * * *',
                    'class' => 'SomeIvarJob',
                    'args' => '/tmp/44'
                }
            )
        )
      end
      Sidekiq.remove_schedule('some_ivar_job3')
      assert_equal nil, Sidekiq.redis{ |r| r.hget(:schedules, 'some_ivar_job3') }
      assert Sidekiq.redis{ |r| r.sismember(:schedules_changed, 'some_ivar_job3') }
    end
  end
end