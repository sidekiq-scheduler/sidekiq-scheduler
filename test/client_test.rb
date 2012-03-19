require 'test_helper'
require 'timecop'

class ClientTest < MiniTest::Unit::TestCase
  describe 'with real redis' do
    before do
      Sidekiq.redis = { :url => 'redis://localhost/sidekiq_test' }
      Sidekiq.redis.flushdb
    end

    it 'removes scheduled messages and returns count' do
      Sidekiq::Client.delayed_push(1331284491, 'class' => 'Foo', 'args' => [1, 2])
      assert_equal 1, Sidekiq::Client.remove_all_delayed('Foo', 1, 2)
    end

    it 'removes scheduled messages for a queue and returns count' do
      Sidekiq::Client.delayed_push('foo', 1331284491, 'class' => 'Foo', 'args' => [1, 2])
      assert_equal 1, Sidekiq::Client.remove_all_delayed_from_queue('foo', 'Foo', 1, 2)
    end

    it 'removes only selected scheduled messages' do
      Sidekiq::Client.delayed_push(1331284491, 'class' => 'Foo', 'args' => [1, 2])
      Sidekiq::Client.delayed_push(1331284491, 'class' => 'Foo', 'args' => [3, 4])
      Sidekiq::Client.delayed_push(1331284491, 'class' => 'Foo', 'args' => [3, 4])
      Sidekiq::Client.delayed_push(1331284491, 'class' => 'Foo', 'args' => [5, 6])
      assert_equal 0, Sidekiq::Client.remove_all_delayed('Foo')
    end

    it 'removes messages in different timestamp queues' do
      Sidekiq::Client.delayed_push(1331284491, 'class' => 'Foo', 'args' => [1, 2])
      Sidekiq::Client.delayed_push(1331284492, 'class' => 'Foo', 'args' => [3, 4])
      Sidekiq::Client.delayed_push(1331284493, 'class' => 'Foo', 'args' => [3, 4])
      Sidekiq::Client.delayed_push(1331284493, 'class' => 'Foo', 'args' => [5, 6])
      assert_equal 2, Sidekiq::Client.remove_all_delayed('Foo', 3, 4)
    end

    it 'handles removed_delayed from a worker' do
      Sidekiq::Client.delayed_push(1331284491, 'class' => 'MyWorker', 'args' => [1, 2])
      Sidekiq::Client.delayed_push(1331284492, 'class' => 'MyWorker', 'args' => [3, 4])
      Sidekiq::Client.delayed_push(1331284493, 'class' => 'MyWorker', 'args' => [3, 4])
      Sidekiq::Client.delayed_push(1331284493, 'class' => 'MyWorker', 'args' => [5, 6])
      assert_equal 2, MyWorker.remove_delayed(3, 4)
    end

    it 'removes messages from specified timestamp' do
      Sidekiq::Client.delayed_push(1331284491, 'class' => 'Foo', 'args' => [1, 2])
      Sidekiq::Client.delayed_push(1331284492, 'class' => 'Foo', 'args' => [1, 2])
      assert_equal 1, Sidekiq::Client.remove_delayed(1331284491, 'Foo', 1, 2)
      assert_equal 1, Sidekiq.redis.llen('delayed:1331284492')
    end

    it 'removes messages from a worker for a specified timestamp' do
      Sidekiq::Client.delayed_push(1331284491, 'class' => 'MyWorker', 'args' => [1, 2])
      Sidekiq::Client.delayed_push(1331284492, 'class' => 'MyWorker', 'args' => [1, 2])
      assert_equal 1, MyWorker.remove_delayed_from_timestamp(1331284491, 1, 2)
      assert_equal 1, Sidekiq.redis.llen('delayed:1331284492')
    end

    it 'removes messages for a queue from specified timestamp' do
      Sidekiq::Client.delayed_push('foo', 1331284491, 'class' => 'Foo', 'args' => [1, 2])
      Sidekiq::Client.delayed_push('foo', 1331284492, 'class' => 'Foo', 'args' => [1, 2])
      assert_equal 1, Sidekiq::Client.remove_delayed_from_queue('foo', 1331284491, 'Foo', 1, 2)
      assert_equal 1, Sidekiq.redis.llen('delayed:1331284492')
    end

    it 'removes nothing if no message is found' do
      assert_equal 0, Sidekiq::Client.remove_delayed(1331284491, 'Foo', 3, 4)
    end

    it 'removes only messages with matching arguments' do
      Sidekiq::Client.delayed_push(1331284491, 'class' => 'Foo', 'args' => [1, 2])
      Sidekiq::Client.delayed_push(1331284491, 'class' => 'Foo', 'args' => [3, 2])
      assert_equal 0, Sidekiq::Client.remove_delayed(1331284491, 'Foo', 3, 4)
      assert_equal 2, Sidekiq.redis.llen('delayed:1331284491')
    end

    it 'removes empty scheduler queues' do
      Sidekiq::Client.delayed_push(1331284491, 'class' => 'Foo', 'args' => [1, 2])
      assert_equal 1, Sidekiq::Client.remove_delayed(1331284491, 'Foo', 1, 2)
      assert !Sidekiq.redis.exists('delayed:1331284491')
      assert_equal 0, Sidekiq.redis.zcard('delayed_scheduler_queue')
    end
  end

  describe 'with mock redis' do
    before do
      @redis = MiniTest::Mock.new
      def @redis.multi; yield; end
      def @redis.set(*); true; end
      def @redis.sadd(*); true; end
      def @redis.srem(*); true; end
      def @redis.get(*); nil; end
      def @redis.del(*); nil; end
      def @redis.incrby(*); nil; end
      def @redis.setex(*); nil; end
      def @redis.expire(*); true; end
      def @redis.with_connection; yield self; end
      def @redis.with; yield self; end
      Sidekiq.instance_variable_set(:@redis, @redis)
    end

    it 'pushes delayed messages to redis' do
      @redis.expect :rpush, 1, ['delayed:1331284491', String]
      @redis.expect :zadd, 1, ['delayed_queue_schedule', 1331284491, 1331284491]
      Sidekiq::Client.delayed_push('foo', 1331284491, 'class' => 'Foo', 'args' => [1, 2])
      @redis.verify
    end

    it 'removes empty scheduler queues' do
      @redis.expect :llen, 0, ['delayed:1331284491']
      @redis.expect :zrem, 1, ['delayed_queue_schedule', 1331284491]
      Sidekiq::Client.remove_scheduler_queue(1331284491)
      @redis.verify
    end

    it 'handles perform_at' do
      @redis.expect :rpush, 1, ['delayed:1331284491', String]
      @redis.expect :zadd, 1, ['delayed_queue_schedule', 1331284491, 1331284491]
      MyWorker.perform_at(1331284491, 1, 2)
      @redis.verify
    end

    it 'handles perform_in' do
      Timecop.freeze(Time.now) do
        timestamp = Time.now + 30
        @redis.expect :rpush, 1, ["delayed:#{timestamp.to_i}", String]
        @redis.expect :zadd, 1, ['delayed_queue_schedule', timestamp.to_i, timestamp.to_i]
        MyWorker.perform_in(30, 1, 2)
        @redis.verify
      end
    end
  end
end
