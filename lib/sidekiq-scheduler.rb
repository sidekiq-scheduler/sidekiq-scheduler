require 'sidekiq'
require 'tilt/erb'

require_relative 'sidekiq-scheduler/version'
require_relative 'sidekiq-scheduler/manager'

Sidekiq.configure_server do |config|

  config.on(:startup) do
    dynamic = Sidekiq::Scheduler.dynamic
    dynamic = dynamic.nil? ? config.options.fetch(:dynamic, false) : dynamic

    enabled = Sidekiq::Scheduler.enabled
    enabled = enabled.nil? ? config.options.fetch(:enabled, true) : enabled

    scheduler_options = {
      scheduler: config.options.fetch(:scheduler, true),
      dynamic:   dynamic,
      enabled:   enabled,
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
