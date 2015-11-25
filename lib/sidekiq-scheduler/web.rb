module SidekiqScheduler
  # Hook into *Sidekiq::Web* Sinatra app which adds a new '/recurring-jobs' page

  module Web
    VIEW_PATH = File.expand_path('../../../web/views', __FILE__)

    def self.registered(app)
      app.get '/recurring-jobs' do
        @schedule = (Sidekiq.schedule! || [])

        erb File.read(File.join(VIEW_PATH, 'recurring_jobs.erb'))
      end
    end
  end
end

require 'sidekiq/web' unless defined?(Sidekiq::Web)
Sidekiq::Web.register(SidekiqScheduler::Web)
Sidekiq::Web.tabs['Recurring Jobs'] = 'recurring-jobs'
