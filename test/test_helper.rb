require 'minitest/unit'
require 'minitest/pride'
require 'minitest/autorun'
require 'sidekiq-scheduler'

require 'sidekiq'
require 'sidekiq/util'
if Sidekiq.respond_to?(:logger)
  Sidekiq.logger.level = Logger::ERROR
else
  Sidekiq::Util.logger.level = Logger::ERROR
end

# Load support files
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }

require 'sidekiq/redis_connection'
REDIS = Sidekiq::RedisConnection.create(:url => "redis://localhost/15", :namespace => 'testy')
