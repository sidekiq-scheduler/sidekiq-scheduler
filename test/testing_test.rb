require 'test_helper'
require 'sidekiq-scheduler/worker'

class TestingTest < MiniTest::Unit::TestCase
  describe 'sidekiq-scheduler testing' do

    it 'stubs the perform_* calls when in testing mode' do
      begin
        require 'sidekiq-scheduler/testing'
        # perform_at
        assert_equal 0, DirectWorker.jobs.size
        assert DirectWorker.perform_at(1331759054, 1, 2)
        assert_equal 1, DirectWorker.jobs.size
        assert_equal 1331759054, DirectWorker.jobs[0]['timestamp']
        DirectWorker.jobs.clear

        # perform_in
        Timecop.freeze(Time.now) do
          timestamp = Time.now + 30
          assert_equal 0, DirectWorker.jobs.size
          assert DirectWorker.perform_in(30, 1, 2)
          assert_equal 1, DirectWorker.jobs.size
          assert_equal timestamp.to_i, DirectWorker.jobs[0]['timestamp']
        end
      ensure
        # Undo override
        SidekiqScheduler::Worker::ClassMethods.class_eval do
          remove_method :perform_at, :perform_in, :remove_delayed, :remove_delayed_from_timestamp
          alias_method :perform_at, :perform_at_old
          alias_method :perform_in, :perform_in_old
          alias_method :remove_delayed, :remove_delayed_old
          alias_method :remove_delayed_from_timestamp, :remove_delayed_from_timestamp_old
          remove_method :perform_at_old, :perform_in_old, :remove_delayed_old, :remove_delayed_from_timestamp_old
        end
      end
    end
  end
end
