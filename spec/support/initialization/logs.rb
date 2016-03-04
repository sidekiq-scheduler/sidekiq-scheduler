require 'sidekiq'
require 'sidekiq/util'
require 'active_job'

if Sidekiq.respond_to?(:logger)
  Sidekiq.logger.level = Logger::ERROR
else
  Sidekiq::Util.logger.level = Logger::ERROR
end

ActiveJob::Base.logger.level = Logger::ERROR
