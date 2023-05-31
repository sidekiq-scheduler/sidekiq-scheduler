# 5.0.3

  - [**FIX**] Fix "uppercase character in header name: Cache-Control" [#432](https://github.com/sidekiq-scheduler/sidekiq-scheduler/pull/432)
  - [**ENHANCEMENT**] Add gd translation [#433](https://github.com/sidekiq-scheduler/sidekiq-scheduler/pull/433)
  - [**ENHANCEMENT**] Add French translation [#435](https://github.com/sidekiq-scheduler/sidekiq-scheduler/pull/435)
  - [**FIX**] Remove usage of deprecated Redis command `zrangebyscore` [#437](https://github.com/sidekiq-scheduler/sidekiq-scheduler/pull/437)
  - [**ENHANCEMENT**] Add the ability to force a job args hash to be deconstructed to keyword arguments [#440](https://github.com/sidekiq-scheduler/sidekiq-scheduler/pull/440)

# 5.0.2

  - [**FIX**] Fix YARD docblocks. [#427](https://github.com/sidekiq-scheduler/sidekiq-scheduler/pull/427)
  - [**FIX**] Fix dependency requirement on Sidekiq reverted unintentionally. [#429](https://github.com/sidekiq-scheduler/sidekiq-scheduler/issues/429)

# 5.0.1

  - [**ENHANCEMENT**] Adds Ruby 3.2 to the CI matrix. [#420](https://github.com/sidekiq-scheduler/sidekiq-scheduler/pull/420)
  - [**DOCS**] README: refer to v5 as released. [#421](https://github.com/sidekiq-scheduler/sidekiq-scheduler/pull/421)
  - [**FIX**] Fix dependency on Rails `.present?` method. [#425](https://github.com/sidekiq-scheduler/sidekiq-scheduler/pull/425)
 
# 5.0.0

  - [**FIX**] Ensure generated scheduled time has a precision of 3 miliseconds. [#418](https://github.com/sidekiq-scheduler/sidekiq-scheduler/pull/418)

*Note 1:* Check [# 5.0.0.beta1](#500beta1) & [# 5.0.0.beta2](#500beta2) releases for breaking changes.

*Note 2:* Sidekiq Embedding is yet not supported, see [#419](https://github.com/sidekiq-scheduler/sidekiq-scheduler/issues/419) for more details.


# 5.0.0.beta2

  - [**FIX**] Drop explicit redis dependency [#416](https://github.com/sidekiq-scheduler/sidekiq-scheduler/pull/416)

# 5.0.0.beta1

- [**BREAKING CHANGE**] Moves all sidekiq-scheduler config options under the `scheduler` key in the `sidekiq.yml` file [#412](https://github.com/sidekiq-scheduler/sidekiq-scheduler/pull/412)
  - If you're migrating from v4 to v5, any `sidekiq-scheduler` config you may have in your `sidekiq.yml` should be moved under the `scheduler` key.
  - See [#412](https://github.com/sidekiq-scheduler/sidekiq-scheduler/pull/412) to see which are the config options that you need to move under the `scheduler` key.
  
- [**BREAKING CHANGE**] Drop support for EOL Ruby & Sidekiq versions (Ruby: `2.5.x` & `2.6.x`; Sidekiq: `4.x` & `5.x`) [#411](https://github.com/sidekiq-scheduler/sidekiq-scheduler/pull/411)

- [**FIX**] Add support for Sidekiq 7 [#410](https://github.com/sidekiq-scheduler/sidekiq-scheduler/pull/410)


# 4.0.3

- [**GH Actions**] Add dependabot for GitHub Actions [#390](https://github.com/sidekiq-scheduler/sidekiq-scheduler/pull/390)
- [**ENHANCEMENT**] Add «Enable all» and «Disable all» buttons [#398](https://github.com/sidekiq-scheduler/sidekiq-scheduler/pull/398)
- [**ENHANCEMENT**] Allow for multiple applications to share a Redis DB [#401](https://github.com/sidekiq-scheduler/sidekiq-scheduler/pull/401)
- [**FIX**] Fix metadata for Sidekiq strict_args! [#403](https://github.com/sidekiq-scheduler/sidekiq-scheduler/pull/403)
- [**FIX**] Redis 5.0 compatibility [#404](https://github.com/sidekiq-scheduler/sidekiq-scheduler/pull/404)
- [**FIX**] Fix the constantize method [#408](https://github.com/sidekiq-scheduler/sidekiq-scheduler/pull/408)

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