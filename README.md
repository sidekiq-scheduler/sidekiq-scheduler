# sidekiq-scheduler

<p align="center">
  <a href="http://sidekiq-scheduler.github.io/sidekiq-scheduler/">
    <img src="https://sidekiq-scheduler.github.io/sidekiq-scheduler/images/small-logo.svg" width="468px" height="200px" alt="Sidekiq Scheduler" />
  </a>
</p>

<p align="center">
  <a href="https://badge.fury.io/rb/sidekiq-scheduler">
    <img src="https://badge.fury.io/rb/sidekiq-scheduler.svg" alt="Gem Version">
  </a>
  <a href="http://www.rubydoc.info/github/sidekiq-scheduler/sidekiq-scheduler">
    <img src="https://img.shields.io/badge/yard-docs-blue.svg" alt="Documentation">
  </a>
</p>

`sidekiq-scheduler` is an extension to [Sidekiq](http://github.com/mperham/sidekiq) that
pushes jobs in a scheduled way, mimicking cron utility.

__Note:__ Current branch contains work of the v6 release, if you are looking for version 2.2.\*, 3.\*, 4.\*, or 5.\*, go to [2.2-stable branch](https://github.com/sidekiq-scheduler/sidekiq-scheduler/tree/2.2-stable) / [v3-stable](https://github.com/sidekiq-scheduler/sidekiq-scheduler/tree/v3-stable) / [v4-stable](https://github.com/sidekiq-scheduler/sidekiq-scheduler/tree/v4-stable) / [v5-stable](https://github.com/sidekiq-scheduler/sidekiq-scheduler/tree/v5-stable).

## Installation

``` shell
gem install sidekiq-scheduler
```

## Usage

### Hello World


``` ruby
# hello-scheduler.rb

require 'sidekiq-scheduler'

class HelloWorld
  include Sidekiq::Job

  def perform
    puts 'Hello world'
  end
end
```

__Note:__ In Sidekiq v6.3 `Sidekiq::Job` was introduced as an alias for `Sidekiq::Worker`. `Sidekiq::Worker` has been officially deprecated in Sidekiq v7 although it still exists for backwards compatibility. It is therefore recommended to use `include Sidekiq::Job` in the above example unless an older version of Sidekiq is required.

``` yaml
# config/sidekiq.yml

:scheduler:
  :schedule:
    hello_world:
      cron: '0 * * * * *'   # Runs once per minute
      class: HelloWorld
```

> [!NOTE]
> sidekiq-scheduler uses [fugit](https://github.com/floraison/fugit) under the hood, which supports up to six arguments as the cron string, [see](https://github.com/floraison/fugit?tab=readme-ov-file#the-second-extension).

Run sidekiq:

``` sh
sidekiq -r ./hello-scheduler.rb
```

You'll see the following output:

```
2016-12-10T11:53:08.561Z 6452 TID-ovouhwvm4 INFO: Loading Schedule
2016-12-10T11:53:08.561Z 6452 TID-ovouhwvm4 INFO: Scheduling HelloWorld {"cron"=>"0 * * * * *", "class"=>"HelloWorld"}
2016-12-10T11:53:08.562Z 6452 TID-ovouhwvm4 INFO: Schedules Loaded

2016-12-10T11:54:00.212Z 6452 TID-ovoulivew HelloWorld JID-b35f36a562733fcc5e58444d INFO: start
Hello world
2016-12-10T11:54:00.213Z 6452 TID-ovoulivew HelloWorld JID-b35f36a562733fcc5e58444d INFO: done: 0.001 sec

2016-12-10T11:55:00.287Z 6452 TID-ovoulist0 HelloWorld JID-b7e2b244c258f3cd153c2494 INFO: start
Hello world
2016-12-10T11:55:00.287Z 6452 TID-ovoulist0 HelloWorld JID-b7e2b244c258f3cd153c2494 INFO: done: 0.001 sec
```

## Configuration options

Configuration options are placed inside `sidekiq.yml` config file.

Available options are:

``` yaml
:scheduler:
  :dynamic: <if true the schedule can be modified in runtime [false by default]>
  :dynamic_every: <if dynamic is true, the schedule is reloaded every interval [5s by default]>
  :enabled: <enables scheduler if true [true by default]>
  :listened_queues_only: <push jobs whose queue is being listened by sidekiq [false by default]>
  :rufus_scheduler_options: <Set custom options for rufus scheduler, like max_work_threads [{} by default]>
```

## Schedule configuration

The schedule is configured through the `:scheduler:` -> `:schedule` config entry in the sidekiq config file:

``` yaml
:scheduler:
  :schedule:
    CancelAbandonedOrders:
      cron: '0 */5 * * * *'   # Runs when second = 0, every 5 minutes

    queue_documents_for_indexing:
      cron: '0 0 * * * *'   # Runs every hour

      # By default the job name will be taken as worker class name.
      # If you want to have a different job name and class name, provide the 'class' option
      class: QueueDocuments

      queue: slow
      args: ['*.pdf']
      description: "This job queues pdf content for indexing in solr"

      # Enable the `metadata` argument which will pass a Hash containing the schedule metadata
      # as the last argument of the `perform` method. `false` by default.
      include_metadata: true

      # Enable / disable a job. All jobs are enabled by default.
      enabled: true

      # Deconstructs a hash defined as the `args` to keyword arguments.
      #
      # `false` by default.
      #
      # Example
      #
      # my_job:
      #   cron: '0 0 * * * *'
      #   class: MyJob
      #   args: { foo: 'bar', hello: 'world' }
      #   keyword_argument: true
      #
      # class MyJob < ActiveJob::Base
      #   def perform(foo:, hello:)
      #     # ...
      #   end
      # end
      keyword_argument: true
```

### Schedule metadata
You can configure Sidekiq-scheduler to pass an argument with metadata about the scheduling process
to the worker's `perform` method.

In the configuration file add the following on each worker class entry:

```yaml

  SampleWorker:
    include_metadata: true
```

On your `perform` method, expect an additional argument:

```ruby
  def perform(args, ..., metadata)
    # Do something with the metadata
  end
```

The `metadata` hash contains the following keys:

```ruby
  metadata.keys =>
    [
      :scheduled_at # The epoch when the job was scheduled to run
    ]
```

## Schedule types

Supported types are `cron`, `every`, `interval`, `at`, `in`.

Cron, every, and interval types push jobs into sidekiq in a recurrent manner.

`cron` follows the same pattern as cron utility, with seconds resolution.

``` yaml
:scheduler:
  :schedule:
    HelloWorld:
      cron: '0 * * * * *' # Runs when second = 0
```

`every` triggers following a given frequency:

``` yaml
    every: '45m'    # Runs every 45 minutes
```

The value is parsed by [`Fugit::Duration.parse`](https://github.com/floraison/fugit#fugitduration). It understands quite a number of formats, including human-readable ones:

``` yaml
    every: 45 minutes
    every: 2 hours and 30 minutes
    every: 1.5 hours
```

`interval` is similar to `every`, the difference between them is that `interval` type schedules the
next execution after the interval has elapsed counting from its last job enqueue.

Note that `every` and `interval` count from when the Sidekiq process (re)starts. So `every: '48h'` will never run if the Sidekiq process is restarted daily, for example. You can do `every: ['48h', first_in: '0s']` to make the job run immediately after a restart, and then have the worker check when it was last run.

At, and in types push jobs only once. `at` schedules in a point in time:
``` yaml
    at: '3001/01/01'
```

You can specify any string that `DateTime.parse` and `Chronic` understand. To enable [Chronic](https://github.com/mojombo/chronic)
strings, you must add it as a dependency.

`in` triggers after a time duration has elapsed:

``` yaml
    in: 1h # pushes a sidekiq job in 1 hour, after start-up
```

You can provide options to `every` or `cron` via an Array:

``` yaml
    every: ['30s', first_in: '120s']
```

See https://github.com/jmettraux/rufus-scheduler for more information.

## Load the schedule from a different file

You can place the schedule configuration in a separate file from `config/sidekiq.yml`

``` yaml
# sidekiq_scheduler.yml

clear_leaderboards_contributors:
  cron: '0 30 6 * * 1'
  class: ClearLeaderboards
  queue: low
  args: contributors
  description: 'This job resets the weekly leaderboard for contributions'
```

Please notice that the `schedule` root key is not present in the separate file.

To load the schedule:

``` ruby
require 'sidekiq'
require 'sidekiq-scheduler'

Sidekiq.configure_server do |config|
  config.on(:startup) do
    Sidekiq.schedule = YAML.load_file(File.expand_path('../../sidekiq_scheduler.yml', __FILE__))
    SidekiqScheduler::Scheduler.instance.reload_schedule!
  end
end
```

The above code can be placed in an initializer (in `config/initializers`) that runs every time the app starts up.

## Dynamic schedule

The schedule can be modified after startup. To add / update a schedule, you have to:

``` ruby
Sidekiq.set_schedule('heartbeat', { 'every' => ['1m'], 'class' => 'HeartbeatWorker' })
```

If the schedule did not exist it will be created, if it existed it will be updated.

When `:dynamic` flag is set to `true`, schedule changes are loaded every 5 seconds. Use the `:dynamic_every` flag for a different interval.

``` yaml
# config/sidekiq.yml
:scheduler:
  :dynamic: true
```

If `:dynamic` flag is set to `false`, you'll have to reload the schedule manually in sidekiq
side:

``` ruby
SidekiqScheduler::Scheduler.instance.reload_schedule!
```

Invoke `Sidekiq.get_schedule` to obtain the current schedule:

``` ruby
Sidekiq.get_schedule
#  => { 'every' => '1m', 'class' => 'HardWorker' }
```

## Time zones

Note that if you use the cron syntax and are not running a Rails app, this will be interpreted in the server time zone.

In a Rails app, [rufus-scheduler](https://github.com/jmettraux/rufus-scheduler) (>= 3.3.3) will use the `config.time_zone` specified in Rails.

You can explicitly specify the time zone that rufus-scheduler will use:

``` yaml
    cron: '0 30 6 * * 1 Europe/Stockholm'
```

Also note that `config.time_zone` in Rails allows for a shorthand (e.g. "Stockholm")
that rufus-scheduler does not accept. If you write code to set the scheduler time zone
from the `config.time_zone` value, make sure it's the right format, e.g. with:

``` ruby
ActiveSupport::TimeZone.find_tzinfo(Rails.configuration.time_zone).name
```

## Notes about connection pooling

If you're configuring your own Redis connection pool, you need to make sure the size is adequate to be inclusive of both Sidekiq's own connection pool and Rufus Scheduler's.

That's a minimum of `concurrency` + 5 (per the [Sidekiq wiki](https://github.com/mperham/sidekiq/wiki/Using-Redis#complete-control)) + `Rufus::Scheduler::MAX_WORK_THREADS` (28 as of this writing; per the [Rufus README](https://github.com/jmettraux/rufus-scheduler#max_work_threads)), for a total of 58 with the default `concurrency` of 25.

You can also override the thread pool size in Rufus Scheduler by setting the following in your `sidekiq.yml` config:

```yaml
---
...

:scheduler:
  rufus_scheduler_options:
    max_work_threads: 5

...
```

## Notes about running on Multiple Hosts

Under normal conditions, `cron` and `at` jobs are pushed once regardless of the number of `sidekiq-scheduler` running instances,
assuming that time deltas between hosts is less than 24 hours.

Non-normal conditions that could push a specific job multiple times are:
 - high cpu load + a high number of jobs scheduled at the same time, like 100 jobs
 - network / redis latency + 28 (see `MAX_WORK_THREADS` https://github.com/jmettraux/rufus-scheduler/blob/master/lib/rufus/scheduler.rb#L41) or more jobs scheduled within the same network latency window

`every`, `interval` and `in` jobs will be pushed once per host.

### Suggested setup for Multiple Hosts using Heroku and Rails

Configuration options `every`, `interval` and `in` will push once per host. This may be undesirable. One way to achieve single jobs per the schedule would be to manually designate a host as the scheduler. The goal is to have a single scheduler process running across all your hosts.

This can be achieved by using an environment variable and controlling the number of dynos. In Rails, you can read this variable during initialization and then conditionally load your config file.

Suppose we are using Rails and have the following schedule:

```yaml
# config/scheduler.yml
MyRegularJob:
  description: "We want this job to run very often, but we do not want to run more of them as we scale"
  interval: ["1m"]
  queue: default
```

Then we can conditionally load it via an initializer:

```ruby
# config/initializers/sidekiq.rb
if ENV.fetch("IS_SCHEDULER", false)
  Sidekiq.configure_server do |config|
    config.on(:startup) do
      Sidekiq.schedule = YAML.load_file(File.expand_path("../scheduler.yml", File.dirname(__FILE__)))
      Sidekiq::Scheduler.reload_schedule!
    end
  end
end
```

Then you would just need to flag the scheduler process when you start it. If you are using a Procfile, it would look like this:

```yaml
# Procfile
web: bin/rails server
worker: bundle exec sidekiq -q default
scheduler: IS_SCHEDULER=true bundle exec sidekiq -q default
```

When running via Heroku, you set your `scheduler` process to have 1 dyno. This will ensure you have at most 1 worker loading the schedule.

## Notes on when Sidekiq worker is down

For a `cron`/`at` (and all other) job to be successfully enqueued, you need at least one sidekiq worker with scheduler to be up at that moment. Handling this is up to you and depends on your application.

Possible solutions include:
- Simply ignoring this fact, if you only run frequent periodic jobs, that can tolerate some increased interval
- Abstaining from deploys/restarts during time when critical jobs are usually scheduled
- Making your infrequent jobs idempotent (so that they can be enqueued multiple times but still produce result as if was run once) and scheduling them multiple times to reduce likelihood of not being run
- Zero downtime deploy for sidekiq workers: keep at least one worker up during whole deploy and only restart/shut it down after when new one has started
- Running scheduler inside your unicorn/rails processes (if you already have zero downtime deploy set up for these)

Each option has it's own pros and cons.

## Notes when running multiple Sidekiq processors on the same Redis

### TL;DR

Be **sure** to include the `:enabled: false` top-level key on any additional
configurations to avoid any possibility of the `schedules` definition being
wiped by the second Sidekiq process.

To illustrate what we mean:

Say you have one process with the schedule:
```yaml
# e.g., config/sidekiq.yml

:queues:
  - default
:scheduler:
  :schedule:
    do_something_every_minute:
      class: DoSomethingJob
      args: matey
      queue: :scheduler
      cron: '0 * * * * * America/Los_Angeles'
```

And a separate separate configured process without one:
```yaml
# e.g., config/sidekiq_other.yml
:queues:
  - scheduler

## NOTE Disable the Scheduler
:scheduler:
  :enabled: false
```

### Details

This gem stores the configured schedule in Redis on boot. It's used, primarily,
to display in the Web Integration, and allow you to interact with that schedule
via that integration.

If you're running multiple Sidekiq processes on the same Redis namespace with
different configurations, **you'll want to explicitly _disable_ Sidekiq
Scheduler** for the other processes not responsible for the schedule. If you
don't, the last booted Sidekiq processes' schedule will be what is stored in
Redis.

See https://github.com/sidekiq-scheduler/sidekiq-scheduler/issues/361 for a more details.

## Notes when running multiple applications in the same Redis database

_NOTE_: **Although we support this option, we recommend having separate redis databases for each application. Choosing this option is at your own risk.**

If you need to run multiple applications with differing schedules, the easiest way is to use a different Redis database per application. Doing that will ensure that each application will have its own schedule, web interface and statistics.

However, you may want to have a set of related applications share the same Redis database in order to aggregate statistics and manage them all in a single web interface. To do this while maintaining a different schedule for each application, you can configure each application to use a different `key_prefix` in Redis. This prevents the applications overwriting each others' schedules and schedule data.

```ruby
Rails.application.reloader.to_prepare do
  SidekiqScheduler::RedisManager.key_prefix = "my-app"
end
```

Note that this must be set before the schedule is loaded (or it will go into the wrong key). If you are using the web integration, make sure that the prefix is set in the web process so that you see the correct schedule.

## Sidekiq Web Integration

sidekiq-scheduler provides an extension to the Sidekiq web interface that adds a `Recurring Jobs` page.

``` ruby
# config.ru

require 'sidekiq/web'
require 'sidekiq-scheduler/web'

run Sidekiq::Web
```

![Sidekiq Web Integration](https://github.com/sidekiq-scheduler/sidekiq-scheduler/raw/master/images/recurring-jobs-ui-tab.png)

## ActiveJob integration

When using sidekiq-scheduler with ActiveJob your jobs can just extend `ApplicationJob` as usual, without the `require` and `include` boilerplate. Under the hood Rails will load up the scheduler and include the worker module for you.

```rb
class HelloWorld < ApplicationJob
  def perform
    puts 'Hello world'
  end
end
```

## The Spring preloader and Testing your initializer via Rails console

If you're pulling in your schedule from a YML file via an initializer as shown, be aware that the Spring application preloader included with Rails will interfere with testing via the Rails console.

**Spring will not reload initializers** unless the initializer is changed.  Therefore, if you're making a change to your YML schedule file and reloading Rails console to see the change, Spring will make it seem like your modified schedule is not being reloaded.

To see your updated schedule, be sure to reload Spring by stopping it prior to booting the Rails console.

Run `spring stop` to stop Spring.

For more information, see [this issue](https://github.com/sidekiq-scheduler/sidekiq-scheduler/issues/35#issuecomment-48067183) and [Spring's README](https://github.com/rails/spring/blob/master/README.md).


## Manage tasks from Unicorn/Rails server

If you want start sidekiq-scheduler only from Unicorn/Rails, but not from sidekiq you can have
something like this in an initializer:

``` ruby
# config/initializers/sidekiq_scheduler.rb
require 'sidekiq'
require 'sidekiq-scheduler'

puts "Sidekiq.server? is #{Sidekiq.server?.inspect}"
puts "defined?(Rails::Server) is #{defined?(Rails::Server).inspect}"
puts "defined?(Unicorn) is #{defined?(Unicorn).inspect}"

if Rails.env == 'production' && (defined?(Rails::Server) || defined?(Unicorn))
  Sidekiq.configure_server do |config|

    config.on(:startup) do
      Sidekiq.schedule = YAML.load_file(File.expand_path('../../scheduler.yml', __FILE__))
      SidekiqScheduler::Scheduler.instance.reload_schedule!
    end
  end
else
  SidekiqScheduler::Scheduler.instance.enabled = false
  puts "SidekiqScheduler::Scheduler.instance.enabled is #{SidekiqScheduler::Scheduler.instance.enabled.inspect}"
end
```

## License

MIT License

## Copyright

- Copyright 2021 - 2024 Marcelo Lauxen.
- Copyright 2013 - 2022 Moove-IT.
- Copyright 2012 Morton Jonuschat.
- Some parts copyright 2010 Ben VandenBos.
