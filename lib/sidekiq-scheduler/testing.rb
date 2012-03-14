require 'sidekiq/testing'

module SidekiqScheduler
  module Worker
    module ClassMethods
      alias_method :perform_at_old, :perform_at
      def perform_at(timestamp, *args)
        jobs << { 'class' => self.name, 'timestamp' => timestamp.to_i, 'args' => args }
        true
      end

      alias_method :perform_in_old, :perform_in
      def perform_in(seconds_from_now, *args)
        timestamp = Time.now + seconds_from_now
        jobs << { 'class' => self.name, 'timestamp' => timestamp.to_i, 'args' => args }
      end

      alias_method :remove_delayed_old, :remove_delayed
      def remove_delayed(*args)
        old_jobcount = jobs.size
        jobs.reject! { |job| job["class"] == self.name && job["args"] == args }
        old_jobcount - jobs.size
      end

      alias_method :remove_delayed_from_timestamp_old, :remove_delayed_from_timestamp
      def remove_delayed_from_timestamp(timestamp, *args)
        old_jobcount = jobs.size
        jobs.reject! { |job| job["class"] == self.name && job["timestamp"] == timestamp.to_i && job["args"] == args }
        old_jobcount - jobs.size
      end
    end
  end
end
