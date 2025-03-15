require 'sidekiq/web' unless defined?(Sidekiq::Web)

# Locale and asset cache is configured in `cfg.register`
Sidekiq::Web.configure do |cfg|
  cfg.register(SidekiqScheduler::Web,
    name: "recurring_jobs",
    tab: ["Recurring Jobs"],
    index: ["recurring-jobs"],
    root_dir: File.expand_path("../../../web", File.dirname(__FILE__)),
    asset_paths: ["stylesheets-scheduler"]) do |app|
    # add middleware or additional settings here
  end
end
