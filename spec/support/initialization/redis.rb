require 'mock_redis'
require 'sidekiq/redis_connection'

RSpec.configure do |config|
  config.before do
    redis = MockRedis.new
    client = Object.new

    client.define_singleton_method(:id) do
      "redis://127.0.0.1:1234/0"
    end

    allow(redis).to receive(:client).and_return(client)

    allow(Sidekiq::RedisConnection).to receive(:create).and_return(ConnectionPool.new({}) {
      redis
    })
  end
end
