require 'sidekiq-scheduler/manager'
require 'sidekiq/cli'

module SidekiqScheduler
  module CLI
    def self.included(base)
      base.class_eval do
        alias_method :run_manager, :run
        alias_method :run, :run_scheduler
      end
    end

    def run_scheduler
      scheduler_options = { :scheduler => true, :schedule => nil }
      scheduler_options.merge!(options)

      if options[:config_file]
        file_options = YAML.load_file(options[:config_file])
        options.merge!(file_options)
        options.delete(:config_file)
        parse_queues(options, options.delete(:queues) || [])
      end

      scheduler = SidekiqScheduler::Manager.new(scheduler_options)
      scheduler.start
      run_manager
      scheduler.stop
    end
  end
end

Sidekiq::CLI.send(:include, SidekiqScheduler::CLI)