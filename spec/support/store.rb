module SidekiqScheduler
  module Store
    def self.clean
      Sidekiq.redis(&:flushall)
    end

    def self.job_from_redis(job_id)
      job = job_from_redis_without_decoding(job_id)
      JSON.parse(job)
    end

    def self.changed_job?(job_id)
      Sidekiq.redis { |redis| !!redis.zrank('schedules_changed', job_id) }
    end

    def self.job_from_redis_without_decoding(job_id)
      Sidekiq.redis { |redis| redis.hget('schedules', job_id) }
    end

    def self.job_next_execution_time(job_name)
      Sidekiq.redis { |r| r.hget(SidekiqScheduler::RedisManager.next_times_key, job_name) }
    end

    def self.job_last_execution_time(job_name)
      Sidekiq.redis { |r| r.hget(SidekiqScheduler::RedisManager.last_times_key, job_name) }
    end

    def self.hget(hash_key, field_key)
      Sidekiq.redis { |r| r.hget(hash_key.to_s, field_key.to_s) }
    end

    def self.hset(hash_key, field_key, value)
      Sidekiq.redis { |r| r.hset(hash_key.to_s, field_key.to_s, value) }
    end

    def self.del(key)
      Sidekiq.redis { |r| r.del(key.to_s) }
    end

    def self.hdel(hash_key, field_key)
      Sidekiq.redis { |r| r.hdel(hash_key.to_s, field_key.to_s) }
    end

    def self.sadd(set_key, field_key)
      Sidekiq.redis { |r| r.sadd(set_key.to_s, field_key.to_s) }
    end

    def self.zadd(sorted_set_key, score, field_key)
      Sidekiq.redis { |r| r.zadd(sorted_set_key.to_s, score, field_key.to_s) }
    end

    def self.zrangebyscore(zset_key, from, to)
      Sidekiq.redis { |r| r.zrangebyscore(zset_key, from, to) }
    end

    def self.zrange(zset_key, from, to)
      Sidekiq.redis { |r| r.zrange(zset_key, from, to) }
    end

    def self.exists?(key)
      Sidekiq.redis { |r| r.exists?(key) }
    end

    def self.hexists(hash_key, field_key)
      Sidekiq.redis { |r| r.hexists(hash_key.to_s, field_key.to_s) }
    end
  end
end
