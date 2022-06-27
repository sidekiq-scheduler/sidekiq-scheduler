# 4.0.2

- [**FIX**] Fix sidekiq deprecation warning when Sidekiq 6.5+ [#385](https://github.com/sidekiq-scheduler/sidekiq-scheduler/pull/385)
- [**FIX**] Fix `#print_schedule` calling a method that doesn't exist in rufus scheduler [#388](https://github.com/sidekiq-scheduler/sidekiq-scheduler/pull/388)

# 4.0.1

- [**FIX**] Add support for sidekiq 6.5 [#382](https://github.com/sidekiq-scheduler/sidekiq-scheduler/pull/382)

# 4.0.0

- [**FIX**] Fix CSS not loading on Rails app when Sidekiq < 6 [#377](https://github.com/sidekiq-scheduler/sidekiq-scheduler/pull/377)
- [**BREAKING CHANGE**] Drop support for Sidekiq 3 [f15e7ca1a5f3ab5b6fd3d7664d67723dba1fa1f1](https://github.com/sidekiq-scheduler/sidekiq-scheduler/commit/f15e7ca1a5f3ab5b6fd3d7664d67723dba1fa1f1)

# 4.0.0.alpha1

- [**FIX**] Fix deprecated uses of Redis#pipelined [#357](https://github.com/sidekiq-scheduler/sidekiq-scheduler/pull/357)
- [**DOCS**] Add docs for running multi-sidekiq configurations [#362](https://github.com/sidekiq-scheduler/sidekiq-scheduler/pull/362)
- [**FIX**] Prevent sidekiq_options from overriding ActiveJob queue settings [#367](https://github.com/sidekiq-scheduler/sidekiq-scheduler/pull/367)
- [**ENHANCEMENT**] Highlight disabled jobs [#369](https://github.com/sidekiq-scheduler/sidekiq-scheduler/pull/369)
- [**BREAKING CHANGE**] Require redis 4.2.0 [#370](https://github.com/sidekiq-scheduler/sidekiq-scheduler/pull/370)
- [**FIX**] Fixes redis deprecation warning regarding `exists` [#370](https://github.com/sidekiq-scheduler/sidekiq-scheduler/pull/370)
- [**BREAKING CHANGE**] Remove dependecy on thwait and e2mmap [#371](https://github.com/sidekiq-scheduler/sidekiq-scheduler/pull/371)
- Support Ruby 3.1 [#373](https://github.com/sidekiq-scheduler/sidekiq-scheduler/pull/373)
- [**BREAKING CHANGE**] Set rufus_scheduler_options via sidekiq.yml file as configuration option [#375](https://github.com/sidekiq-scheduler/sidekiq-scheduler/pull/375)