require 'sidekiq/redis_connection'

RSpec.configure do |config|
  config.before do
    Sidekiq.redis { |r| r.flushdb(async: true) }
  end
end
