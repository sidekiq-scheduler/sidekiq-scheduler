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
      options = { :enabled => true, :resolution => 5 }
      scheduler = SidekiqScheduler::Manager.new(options)
      scheduler.start!
      run_manager
      scheduler.stop!
    end
  end
end

Sidekiq::CLI.send(:include, SidekiqScheduler::CLI)
