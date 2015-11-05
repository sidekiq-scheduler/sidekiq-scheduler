# Change Log

## [1.2.3](https://github.com/moove-it/sidekiq-scheduler/tree/1.2.3) (2015-11-05)
[Full Changelog](https://github.com/moove-it/sidekiq-scheduler/compare/v1.2.2...1.2.3)

**Closed issues:**

- Keep the tags up to date? [\#48](https://github.com/moove-it/sidekiq-scheduler/issues/48)
- Scheduler giving timeout errors [\#42](https://github.com/moove-it/sidekiq-scheduler/issues/42)
- Multiple schedules are loaded for multiple workers [\#41](https://github.com/moove-it/sidekiq-scheduler/issues/41)

**Merged pull requests:**

- Update README.md [\#61](https://github.com/moove-it/sidekiq-scheduler/pull/61) ([MaartenG](https://github.com/MaartenG))
- Fixed coveralls integration [\#59](https://github.com/moove-it/sidekiq-scheduler/pull/59) ([elpic](https://github.com/elpic))
- Improve documentation & fixed tests [\#58](https://github.com/moove-it/sidekiq-scheduler/pull/58) ([elpic](https://github.com/elpic))
- Fixed scheduled jobs view [\#57](https://github.com/moove-it/sidekiq-scheduler/pull/57) ([elpic](https://github.com/elpic))
- Add startup and enabled options [\#49](https://github.com/moove-it/sidekiq-scheduler/pull/49) ([artem-russkikh](https://github.com/artem-russkikh))

## [v1.2.2](https://github.com/moove-it/sidekiq-scheduler/tree/v1.2.2) (2015-10-19)
[Full Changelog](https://github.com/moove-it/sidekiq-scheduler/compare/v1.2.1...v1.2.2)

**Closed issues:**

- Not seeing scheduled tasks in web [\#56](https://github.com/moove-it/sidekiq-scheduler/issues/56)
- Issue loading sidekiq-scheduler/web [\#52](https://github.com/moove-it/sidekiq-scheduler/issues/52)

**Merged pull requests:**

- Add web view to gemspec [\#55](https://github.com/moove-it/sidekiq-scheduler/pull/55) ([elpic](https://github.com/elpic))
- Fix typo in README.md [\#51](https://github.com/moove-it/sidekiq-scheduler/pull/51) ([cbetta](https://github.com/cbetta))

## [v1.2.1](https://github.com/moove-it/sidekiq-scheduler/tree/v1.2.1) (2015-10-16)
[Full Changelog](https://github.com/moove-it/sidekiq-scheduler/compare/v1.2...v1.2.1)

**Merged pull requests:**

- Remove useless sidekiq version constraint [\#54](https://github.com/moove-it/sidekiq-scheduler/pull/54) ([snmgian](https://github.com/snmgian))
- Bump version and add CHANGELOG [\#53](https://github.com/moove-it/sidekiq-scheduler/pull/53) ([elpic](https://github.com/elpic))

## [v1.2](https://github.com/moove-it/sidekiq-scheduler/tree/v1.2) (2015-10-16)
[Full Changelog](https://github.com/moove-it/sidekiq-scheduler/compare/v0.4.1...v1.2)

**Closed issues:**

- Reload Schedules [\#45](https://github.com/moove-it/sidekiq-scheduler/issues/45)
- Schedule not being reloaded when starting Rails app [\#35](https://github.com/moove-it/sidekiq-scheduler/issues/35)
- Document config/sidekiq.yml syntax [\#32](https://github.com/moove-it/sidekiq-scheduler/issues/32)
- Sidekiq Version [\#30](https://github.com/moove-it/sidekiq-scheduler/issues/30)
- Not processing jobs, not working. [\#29](https://github.com/moove-it/sidekiq-scheduler/issues/29)
- Buid a new Version [\#28](https://github.com/moove-it/sidekiq-scheduler/issues/28)
- undefined method `start!' for \#\<SidekiqScheduler::Manager:0x007fea3cf29df0\> [\#27](https://github.com/moove-it/sidekiq-scheduler/issues/27)
- CLI is calling start! instead of start as defined in manager [\#26](https://github.com/moove-it/sidekiq-scheduler/issues/26)
- 0.4.1 bug with bang-methods [\#25](https://github.com/moove-it/sidekiq-scheduler/issues/25)
- conflict between sidekiq and sidekiq-scheduler [\#24](https://github.com/moove-it/sidekiq-scheduler/issues/24)
- Documentation - Resque workers? [\#23](https://github.com/moove-it/sidekiq-scheduler/issues/23)
- WARN: DEPRECATION WARNING: 'bang method'-style async syntax is deprecated [\#19](https://github.com/moove-it/sidekiq-scheduler/issues/19)
- Can't boot sidekiq with daemonize from init script [\#17](https://github.com/moove-it/sidekiq-scheduler/issues/17)
- Future of sidekiq-scheduler. [\#15](https://github.com/moove-it/sidekiq-scheduler/issues/15)
- Future of sidekiq-scheduler. [\#14](https://github.com/moove-it/sidekiq-scheduler/issues/14)

**Merged pull requests:**

- Basic Sidekiq Web UI integration [\#50](https://github.com/moove-it/sidekiq-scheduler/pull/50) ([jimryan](https://github.com/jimryan))
- Update gem version to 1.1 [\#46](https://github.com/moove-it/sidekiq-scheduler/pull/46) ([elpic](https://github.com/elpic))
- allow the use of rufus scheduler methods \[at, in\] [\#44](https://github.com/moove-it/sidekiq-scheduler/pull/44) ([timcase](https://github.com/timcase))
- Fix "every" syntax example [\#43](https://github.com/moove-it/sidekiq-scheduler/pull/43) ([dlubarov](https://github.com/dlubarov))
- Can pass options to Rufus::Scheduler.new [\#38](https://github.com/moove-it/sidekiq-scheduler/pull/38) ([ecin](https://github.com/ecin))
- Adding note about the Spring preloader and testing initializer to README [\#37](https://github.com/moove-it/sidekiq-scheduler/pull/37) ([shedd](https://github.com/shedd))
- Update README.md [\#31](https://github.com/moove-it/sidekiq-scheduler/pull/31) ([tjgillies](https://github.com/tjgillies))
- Test suite fails: Celluloid::Error: Thread pool is not running [\#22](https://github.com/moove-it/sidekiq-scheduler/pull/22) ([tskogberg](https://github.com/tskogberg))
- Adding details on how to load the scheduled jobs definition [\#20](https://github.com/moove-it/sidekiq-scheduler/pull/20) ([fabrizioc1](https://github.com/fabrizioc1))
- Travis CI integration [\#18](https://github.com/moove-it/sidekiq-scheduler/pull/18) ([petergoldstein](https://github.com/petergoldstein))
- fix loading YAML config [\#16](https://github.com/moove-it/sidekiq-scheduler/pull/16) ([Raerten](https://github.com/Raerten))

## [v0.4.1](https://github.com/moove-it/sidekiq-scheduler/tree/v0.4.1) (2013-01-07)
[Full Changelog](https://github.com/moove-it/sidekiq-scheduler/compare/v0.4.0...v0.4.1)

**Closed issues:**

- JRuby 1.7.0 constantize error [\#12](https://github.com/moove-it/sidekiq-scheduler/issues/12)

**Merged pull requests:**

- fixed jruby 1.7 [\#13](https://github.com/moove-it/sidekiq-scheduler/pull/13) ([mimosz](https://github.com/mimosz))

## [v0.4.0](https://github.com/moove-it/sidekiq-scheduler/tree/v0.4.0) (2012-08-26)
[Full Changelog](https://github.com/moove-it/sidekiq-scheduler/compare/v0.3.2...v0.4.0)

**Closed issues:**

- how to run [\#9](https://github.com/moove-it/sidekiq-scheduler/issues/9)
- Sidekiq Web [\#7](https://github.com/moove-it/sidekiq-scheduler/issues/7)

**Merged pull requests:**

- Added suport for cron like schedules [\#11](https://github.com/moove-it/sidekiq-scheduler/pull/11) ([adrian-gomez](https://github.com/adrian-gomez))
- Clarify testing support, and mention perform\_in seconds input for non-Rails users [\#10](https://github.com/moove-it/sidekiq-scheduler/pull/10) ([kyledrake](https://github.com/kyledrake))
- capistrano task [\#8](https://github.com/moove-it/sidekiq-scheduler/pull/8) ([mustafaturan](https://github.com/mustafaturan))

## [v0.3.2](https://github.com/moove-it/sidekiq-scheduler/tree/v0.3.2) (2012-04-24)
[Full Changelog](https://github.com/moove-it/sidekiq-scheduler/compare/v0.3.1...v0.3.2)

## [v0.3.1](https://github.com/moove-it/sidekiq-scheduler/tree/v0.3.1) (2012-04-13)
[Full Changelog](https://github.com/moove-it/sidekiq-scheduler/compare/v0.3.0...v0.3.1)

## [v0.3.0](https://github.com/moove-it/sidekiq-scheduler/tree/v0.3.0) (2012-04-11)
[Full Changelog](https://github.com/moove-it/sidekiq-scheduler/compare/v0.2.1...v0.3.0)

**Closed issues:**

- Job is run once. [\#6](https://github.com/moove-it/sidekiq-scheduler/issues/6)
- Fatal error in sidekiq, scheduler loop died [\#5](https://github.com/moove-it/sidekiq-scheduler/issues/5)
- Jobs based on fixed schedule [\#3](https://github.com/moove-it/sidekiq-scheduler/issues/3)

**Merged pull requests:**

- Sidekiq 0.11.2 compatibility [\#4](https://github.com/moove-it/sidekiq-scheduler/pull/4) ([captainbeardo](https://github.com/captainbeardo))

## [v0.2.1](https://github.com/moove-it/sidekiq-scheduler/tree/v0.2.1) (2012-03-27)
[Full Changelog](https://github.com/moove-it/sidekiq-scheduler/compare/v0.2.0...v0.2.1)

## [v0.2.0](https://github.com/moove-it/sidekiq-scheduler/tree/v0.2.0) (2012-03-19)
[Full Changelog](https://github.com/moove-it/sidekiq-scheduler/compare/v0.1.2...v0.2.0)

## [v0.1.2](https://github.com/moove-it/sidekiq-scheduler/tree/v0.1.2) (2012-03-14)
[Full Changelog](https://github.com/moove-it/sidekiq-scheduler/compare/v0.1.1...v0.1.2)

## [v0.1.1](https://github.com/moove-it/sidekiq-scheduler/tree/v0.1.1) (2012-03-14)
[Full Changelog](https://github.com/moove-it/sidekiq-scheduler/compare/v0.1.0...v0.1.1)

## [v0.1.0](https://github.com/moove-it/sidekiq-scheduler/tree/v0.1.0) (2012-03-13)
[Full Changelog](https://github.com/moove-it/sidekiq-scheduler/compare/v0.0.0...v0.1.0)

## [v0.0.0](https://github.com/moove-it/sidekiq-scheduler/tree/v0.0.0) (2012-03-12)
[Full Changelog](https://github.com/moove-it/sidekiq-scheduler/compare/semver...v0.0.0)

## [semver](https://github.com/moove-it/sidekiq-scheduler/tree/semver) (2012-03-12)


\* *This Change Log was automatically generated by [github_changelog_generator](https://github.com/skywinder/Github-Changelog-Generator)*