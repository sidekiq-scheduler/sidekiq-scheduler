require 'sidekiq/web' unless defined?(Sidekiq::Web)

# Locale and asset cache is configured in `cfg.register`
args = {
  name: "recurring_jobs",
  tab: ["Recurring Jobs"],
  index: ["recurring-jobs"],
  root_dir: File.expand_path("../../../web", File.dirname(__FILE__)),
  asset_paths: ["stylesheets-scheduler"]
}

if SidekiqScheduler::SidekiqAdapter::SIDEKIQ_GTE_8_0_0
  Sidekiq::Web.configure do |cfg|
    cfg.register(SidekiqScheduler::Web, **args) do |app|
      # add middleware or additional settings here
    end
  end
else
  Sidekiq::Web.register(SidekiqScheduler::Web, **args) do |app|
    # add middleware or additional settings here
  end
end
