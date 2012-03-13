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
    end
  end
end

Sidekiq::Worker::ClassMethods.send(:include, SidekiqScheduler::Worker::ClassMethods)
