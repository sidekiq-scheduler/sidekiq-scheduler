module SidekiqScheduler
  module Store

    def self.job_from_redis(job_id)
      job = job_from_redis_without_decoding(job_id)
      JSON.parse(job)
    end

    def self.changed_job?(job_id)
      Sidekiq.redis { |redis| !!redis.zrank(:schedules_changed, job_id) }
    end

    def self.job_from_redis_without_decoding(job_id)
      Sidekiq.redis { |redis| redis.hget(:schedules, job_id) }
    end

    def self.job_next_execution_time(job_name)
      Sidekiq.redis { |r| r.hget(Sidekiq::Scheduler.next_times_key, job_name) }
    end

    def self.job_last_execution_time(job_name)
      Sidekiq.redis { |r| r.hget(Sidekiq::Scheduler.last_times_key, job_name) }
    end
  end
end
