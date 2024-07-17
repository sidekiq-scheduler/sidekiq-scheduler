require 'sidekiq/web' unless defined?(Sidekiq::Web)

if SidekiqScheduler::SidekiqAdapter::SIDEKIQ_GTE_7_3_0

  # Locale and asset cache is configured in `.register`
  Sidekiq::Web.register(SidekiqScheduler::Web,
    name: "recurring_jobs",
    tab: ["Recurring Jobs"],
    index: ["recurring-jobs"],
    root_dir: File.expand_path("../../../web", File.dirname(__FILE__)),
    asset_paths: ["stylesheets-scheduler"]) do |app|
    # add middleware or additional settings here
  end

else

  ASSETS_PATH = File.expand_path('../../../web/assets', __dir__)

  Sidekiq::Web.register(SidekiqScheduler::Web)
  Sidekiq::Web.tabs['recurring_jobs'] = 'recurring-jobs'
  Sidekiq::Web.locales << File.expand_path("#{File.dirname(__FILE__)}/../../../web/locales")

  Sidekiq::Web.use Rack::Static, urls: ['/recurring_jobs/stylesheets-scheduler'],
                                 root: ASSETS_PATH,
                                 cascade: true,
                                 header_rules: [[:all, { 'cache-control' => 'private, max-age=86400' }]]
end
