require 'sidekiq/web' unless defined?(Sidekiq::Web)

ASSETS_PATH = File.expand_path('../../../../web/assets', __dir__)

Sidekiq::Web.register(SidekiqScheduler::Web)
Sidekiq::Web.tabs['recurring_jobs'] = 'recurring-jobs'
Sidekiq::Web.locales << File.expand_path("#{File.dirname(__FILE__)}/../../../web/locales")
Sidekiq::Web.use Rack::Static, urls: ['/stylesheets'],
                               root: ASSETS_PATH,
                               cascade: true,
                               header_rules: [[:all, { 'Cache-Control' => 'public, max-age=86400' }]]
