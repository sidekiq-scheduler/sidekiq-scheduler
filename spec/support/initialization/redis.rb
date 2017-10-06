require 'mock_redis'
require 'sidekiq/redis_connection'

RSpec.configure do |config|
  config.before do
    redis = MockRedis.new

    connection = {
      location: '127.0.0.1:1234',
      db: '0'
    }

    redis.define_singleton_method(:connection) { connection }

    allow(Sidekiq::RedisConnection).to receive(:create).and_return(ConnectionPool.new({}) {
      redis
    })
  end
end
