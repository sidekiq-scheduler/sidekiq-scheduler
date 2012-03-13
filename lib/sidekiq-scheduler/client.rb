require 'sidekiq-scheduler/worker'
require 'sidekiq/client'

module SidekiqScheduler
  module Client
    # Example usage:
    # Sidekiq::Client.delayed_push('my_queue', Time.now + 600, 'class' => MyWorker, 'args' => ['foo', 1, :bat => 'bar'])
    def delayed_push(queue=nil, timestamp, item)
      raise(ArgumentError, "Message must be a Hash of the form: { 'class' => SomeClass, 'args' => ['bob', 1, :foo => 'bar'] }") unless item.is_a?(Hash)
      raise(ArgumentError, "Message must include a class and set of arguments: #{item.inspect}") if !item['class'] || !item['args']

      timestamp = timestamp.to_i

      item['queue'] = queue.to_s if queue
      item['class'] = item['class'].to_s if !item['class'].is_a?(String)

      # Add item to the list for this timestamp
      Sidekiq.redis.rpush("delayed:#{timestamp}", MultiJson.encode(item))

      # Add timestamp to zset. Score and value are based on the timestamp
      # as querying will be based on that
      Sidekiq.redis.zadd('delayed_queue_schedule', timestamp, timestamp)
    end

    def remove_scheduler_queue(timestamp)
      key = "delayed:#{timestamp}"
      if 0 == Sidekiq.redis.llen(key)
        Sidekiq.redis.del(key)
        Sidekiq.redis.zrem('delayed_queue_schedule', timestamp)
      end
    end

    # Example usage:
    # Sidekiq::Client.remove_all_delayed(MyWorker, 'foo', 1, :bat => 'bar')
    #
    # Returns the number of jobs removed
    #
    # This method can be very expensive since it needs to scan
    # through the delayed queues of all timestamps
    def remove_all_delayed(klass, *args)
      remove_all_delayed_from_queue(nil, klass, *args)
    end

    # Example usage:
    # Sidekiq::Client.remove_all_delayed('foo', MyWorker, 'foo', 1, :bat => 'bar')
    #
    # Returns the number of jobs removed
    #
    # This method can be very expensive since it needs to scan
    # through the delayed queues of all timestamps
    def remove_all_delayed_from_queue(queue, klass, *args)
      count = 0
      item = {'class' => klass.to_s, 'args' => args}
      item['queue'] = queue.to_s if queue
      search = MultiJson.encode(item)
      Array(Sidekiq.redis.keys("delayed:*")).each do |key|
        count += Sidekiq.redis.lrem(key, 0, search)
      end
      count
    end

    # Example usage:
    # Sidekiq::Client.remove_delayed(Time.now + 600, MyWorker, 'foo', 1, :bat => 'bar')
    #
    # Returns the number of jobs removed
    def remove_delayed(timestamp, klass, *args)
      remove_delayed_from_queue(nil, timestamp, klass, *args)
    end


    # Example usage:
    # Sidekiq::Client.remove_delayed('foo', Time.now + 600, MyWorker, 'foo', 1, :bat => 'bar')
    #
    # Returns the number of jobs removed
    def remove_delayed_from_queue(queue, timestamp, klass, *args)
      timestamp = timestamp.to_i
      item = {'class' => klass.to_s, 'args' => args}
      item['queue'] = queue.to_s if queue
      search = MultiJson.encode(item)
      count = Sidekiq.redis.lrem("delayed:#{timestamp}", 0, search)
      remove_scheduler_queue(timestamp)
      count
    end
  end
end

  Sidekiq::Client.send(:extend, SidekiqScheduler::Client)
