# SidekiqScheduler

## Description

sidekiq-scheduler is an extension to [Sidekiq](http://github.com/mperham/sidekiq)
that adds support for queueing jobs in the future.

At the moment job scheduling is only supported in a delayed fashion. Replacing cron
is not the intention of this gem. Delayed jobs are Sidekiq jobs that you want to run
at some point in the future.

The syntax is pretty explanatory:

    MyWorker.perform_in(5.days, 'arg1', 'arg2') # run a job in 5 days
    # or
    MyWorker.perform_at(5.days.from_now, 'arg1', 'arg2') # run job at a specific time

## Installation

    # Rails 3.x: add it to your Gemfile
    gem 'sidekiq-scheduler'

    # Starting the scheduler
    bundle exec sidekiq-scheduler

The scheduler will perform identically to a normal sidekiq worker with
an additional scheduler thread being run - in the default configuration
this will result in 25 worker threads being available on the scheduler
node but all normal configuration options apply.

NOTE: Since it's currently not possible to hook into the default option
parsing provided by sidekiq you will need to use a configuration file to
override the scheduler options. Currently the only option available is

    resolution: <seconds between schedule runs>

The scheduling thread will sleep this many seconds between looking for
jobs that need moving to the worker queue. The default is 5 seconds
which should be fast enough for almost all uses.

NOTE: You DO NOT want to run more than one instance of the scheduler.  Doing
so will result in the same job being queued multiple times.  You only need one
instance of the scheduler running per application, regardless of number of servers.

NOTE: If the scheduler thread goes down for whatever reason, the delayed items
that should have fired during the outage will fire once the scheduler is
started back up again (even if it is on a new machine).

## Delayed jobs

Delayed jobs are one-off jobs that you want to be put into a queue at some point
in the future. The classic example is sending email:

    MyWorker.perform_in(5.days, current_user.id)

This will store the job for 5 days in the Sidekiq delayed queue at which time
the scheduler will pull it from the delayed queue and put it in the appropriate 
work queue for the given job. It will then be processed as soon as a worker is 
available (just like any other Sidekiq job).

The `5.days` syntax will only work if you are using ActiveSupport (Rails). If you
are not using Rails, just provide `perform_in` with the number of seconds.

NOTE: The job does not fire **exactly** at the time supplied. Rather, once that
time is in the past, the job moves from the delayed queue to the actual work
queue and will be completed as workers are free to process it.

Also supported is `MyWork.perform_at` which takes a timestamp to queue the job.

The delayed queue is stored in redis and is persisted in the same way the
standard Sidekiq jobs are persisted (redis writing to disk). Delayed jobs differ
from scheduled jobs in that if your scheduler process is down or workers are
down when a particular job is supposed to be processed, they will simply "catch up"
once they are started again.  Jobs are guaranteed to run (provided they make it
into the delayed queue) after their given queue_at time has passed.

One other thing to note is that insertion into the delayed queue is O(log(n))
since the jobs are stored in a redis sorted set (zset).  I can't imagine this
being an issue for someone since redis is stupidly fast even at log(n), but full
disclosure is always best.

### Removing Delayed jobs

If you have the need to cancel a delayed job, you can do it like this:

    # after you've enqueued a job like:
    MyWorker.perform_at(5.days.from_now, 'arg1', 'arg2')
    # remove the job with exactly the same parameters:
    MyWorker.remove_delayed(<timestamp>, 'arg1', 'arg2')

## Using with Testing

Sidekiq uses a jobs array on workers for testing, which is supported by sidekiq-scheduler when you require the test code:

    require 'sidekiq/testing'
    require 'sidekiq-scheduler/testing'
    
    MyWorker.perform_in 5, 'arg1'
    puts MyWorker.jobs.inspect

## Note on Patches / Pull Requests

* Fork the project.
* Make your feature addition or bug fix.
* Add tests for it. This is important so I don't break it in a future version unintentionally.
* Commit, do not mess with rakefile, version, or history.
  (if you want to have your own version, that is fine but bump version in a commit by itself I can ignore when I pull)
* Send me a pull request. Bonus points for topic branches.

## Credits

This work is a partial port of [resque-scheduler](https://github.com/bvandenbos/resque-scheduler) by Ben VandenBos.  
Modified to work with the Sidekiq queueing library by Morton Jonuschat.

## Maintainers

* [Morton Jonuschat](https://github.com/yabawock)

## License

MIT License

## Copyright

Copyright 2012 Morton Jonuschat  
Some parts copyright 2010 Ben VandenBos  
