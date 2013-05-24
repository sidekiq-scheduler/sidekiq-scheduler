require 'minitest/autorun'
require 'minitest/pride'
require 'minitest/autorun'
require 'sidekiq-scheduler'
require 'mocha/setup'
require 'multi_json'
require 'mock_redis'

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

#Setup redis mock to avoid having a dependency with redis server during tests
#$redis = ConnectionPool.new(:timeout => 1, :size => 1) { MockRedis.new }
#Sidekiq.redis = $redis
#
#class MiniTest::Spec
#  before :each do
#    $redis.with_connection { |conn| conn.flushdb }
#  end
#end
class MiniTest::Spec
  before :each do
    redis = MockRedis.new
    client = Object.new

    redis.stubs(:client).returns(client)
    client.stubs(:location).returns('MockRedis')

    Sidekiq::RedisConnection.stubs(:create).returns(ConnectionPool.new({}) { redis })
  end
end

class SomeJob
  include Sidekiq::Worker
  def self.perform(repo_id, path)
  end
end

class SomeIvarJob < SomeJob
  sidekiq_options :queue => :ivar
end

class SomeRealClass
  include Sidekiq::Worker
  sidekiq_options :queue => :some_real_queue
end
