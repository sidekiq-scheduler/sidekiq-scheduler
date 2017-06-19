class Store
  class << self
    def job_from_redis(job_id)
      job = job_from_redis_without_decoding(job_id)
      JSON.parse(job)
    end

    def changed_job?(job_id)
      Sidekiq.redis { |redis| !!redis.zrank(:schedules_changed, job_id) }
    end

    def job_from_redis_without_decoding(job_id)
      Sidekiq.redis { |redis| redis.hget(:schedules, job_id) }
    end
  end
end
