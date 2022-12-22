require 'sidekiq-scheduler'

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
