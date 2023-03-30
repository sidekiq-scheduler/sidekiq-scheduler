require 'sidekiq/web' unless defined?(Sidekiq::Web)

ASSETS_PATH = File.expand_path('../../../web/assets', __dir__)

Sidekiq::Web.register(SidekiqScheduler::Web)
Sidekiq::Web.tabs['recurring_jobs'] = 'recurring-jobs'
Sidekiq::Web.locales << File.expand_path("#{File.dirname(__FILE__)}/../../../web/locales")

if Sidekiq::VERSION >= '6.0.0'
  Sidekiq::Web.use Rack::Static, urls: ['/stylesheets-scheduler'],
                                 root: ASSETS_PATH,
                                 cascade: true,
                                 header_rules: [[:all, { 'cache-control' => 'public, max-age=86400' }]]
end
