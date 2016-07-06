require 'active_job'

ActiveJob::Base.queue_adapter = :inline
