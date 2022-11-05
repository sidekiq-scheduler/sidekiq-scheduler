require 'sidekiq-scheduler'

# Adds String#starts_with? which is used internally by sidekiq 7 as it assumes ActiveSupport is loaded.
# TODO: Remove once https://github.com/mperham/sidekiq/pull/5621 is released.
require 'active_support/core_ext/string'

require_relative 'job_presenter'

module SidekiqScheduler
  # Hook into *Sidekiq::Web* app which adds a new '/recurring-jobs' page

  module Web
    VIEW_PATH = File.expand_path('../../../web/views', __FILE__)

    def self.registered(app)
      app.get '/recurring-jobs' do
        @presented_jobs = JobPresenter.build_collection(Sidekiq.schedule!)

        erb File.read(File.join(VIEW_PATH, 'recurring_jobs.erb'))
      end

      app.post '/recurring-jobs/:name/enqueue' do
        schedule = Sidekiq.get_schedule(params[:name])
        SidekiqScheduler::Scheduler.instance.enqueue_job(schedule)
        redirect "#{root_path}recurring-jobs"
      end

      app.post '/recurring-jobs/:name/toggle' do
        Sidekiq.reload_schedule!

        SidekiqScheduler::Scheduler.instance.toggle_job_enabled(params[:name])
        redirect "#{root_path}recurring-jobs"
      end

      app.post '/recurring-jobs/toggle-all' do
        SidekiqScheduler::Scheduler.instance.toggle_all_jobs(params[:action] == 'enable')
        redirect "#{root_path}recurring-jobs"
      end
    end
  end
end

require_relative 'extensions/web'
