# 3.2.2

- [FIX] Add support for sidekiq 6.5 #382

# 3.2.1
  - Fix CSS not loading on Rails app when Sidekiq < 6 https://github.com/moove-it/sidekiq-scheduler/pull/377
# 3.2.0

- Fix deprecated uses of Redis#pipelined https://github.com/moove-it/sidekiq-scheduler/pull/357
- Prevent sidekiq_options from overriding ActiveJob queue settings https://github.com/moove-it/sidekiq-scheduler/pull/367
- Highlight disabled jobs https://github.com/moove-it/sidekiq-scheduler/pull/369
