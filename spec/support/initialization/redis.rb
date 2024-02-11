require 'sidekiq/redis_connection'

RSpec.configure do |config|
  config.before do
    if Sidekiq::VERSION >= '7.2'
      Sidekiq.redis { |r| r.flushdb('async') }
    else
      Sidekiq.redis { |r| r.flushdb(async: true) }
    end
  end
end
