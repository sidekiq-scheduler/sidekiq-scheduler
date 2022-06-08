require 'sidekiq'
require 'sidekiq/component'
require 'active_job'

if Sidekiq.respond_to?(:logger)
  Sidekiq.logger.level = Logger::ERROR
else
  Sidekiq::Component.logger.level = Logger::ERROR
end

ActiveJob::Base.logger.level = Logger::ERROR
