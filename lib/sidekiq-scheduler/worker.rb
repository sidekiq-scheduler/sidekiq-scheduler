require 'sidekiq-scheduler/client'
require 'sidekiq/worker'

module SidekiqScheduler
  module Worker
    module ClassMethods
      def perform_at(timestamp, *args)
        Sidekiq::Client.delayed_push(timestamp, 'class' => self.name, 'args' => args)
      end

      def perform_in(seconds_from_now, *args)
        Sidekiq::Client.delayed_push(Time.now + seconds_from_now, 'class' => self.name, 'args' => args)
      end

      def remove_delayed(*args)
        Sidekiq::Client.remove_all_delayed(self.name, *args)
      end

      def remove_delayed_from_timestamp(timestamp, *args)
        Sidekiq::Client.remove_delayed(timestamp, self.name, *args)
      end
    end
  end
end

Sidekiq::Worker::ClassMethods.send(:include, SidekiqScheduler::Worker::ClassMethods)
