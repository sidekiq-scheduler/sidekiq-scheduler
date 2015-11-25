require 'sidekiq'
require 'tilt/erb'

require_relative 'sidekiq-scheduler/version'
require_relative 'sidekiq-scheduler/manager'

Sidekiq.configure_server do |config|

  config.on(:startup) do
    scheduler_options = {
      scheduler: config.options.fetch(:scheduler, true),
      dynamic:   config.options.fetch(:dynamic, false),
      enabled:   config.options.fetch(:enabled, true),
      schedule:  config.options.fetch(:schedule, nil)
    }

    schedule_manager = SidekiqScheduler::Manager.new(scheduler_options)
    config.options[:schedule_manager] = schedule_manager
    config.options[:schedule_manager].start
  end

  config.on(:shutdown) do
    config.options[:schedule_manager].stop
  end

end
