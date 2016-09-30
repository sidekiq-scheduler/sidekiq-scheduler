require 'sidekiq-scheduler/web'
require 'rack/test'

describe Sidekiq::Web do
  include Rack::Test::Methods
  before { Sidekiq.redis(&:flushall) }

  def app
    Sidekiq::Web
  end

  let(:enabled_job_name) { 'Foo Job' }

  let(:disabled_job_name) { 'Bar Job' }

  let(:jobs) do
    {
      enabled_job_name => {
        'class' => 'FooClass',
        'cron' => '0 * * * * US/Eastern',
        'args' => [42],
        'description' => 'Does foo things.',
        'enabled' => true
      },

      disabled_job_name => {
        'class' => 'BarClass',
        'every' => '1h',
        'args' => ['foo', 'bar'],
        'queue' => 'special',
        'enabled' => false
      }
    }
  end

  before do
    Sidekiq.schedule = jobs
  end

  describe '/recurring-jobs' do
    it 'shows schedule' do
      get '/recurring-jobs'

      expect(last_response).to be_ok

      expect(last_response.body).to match(/Foo Job/)
      expect(last_response.body).to match(/FooClass/)
      expect(last_response.body).to match(/0 \* \* \* \* US\/Eastern/)
      expect(last_response.body).to match(/default/)
      expect(last_response.body).to match(/\[42\]/)
      expect(last_response.body).to match(/Does foo things\./)

      expect(last_response.body).to match(/Bar Job/)
      expect(last_response.body).to match(/BarClass/)
      expect(last_response.body).to match(/1h/)
      expect(last_response.body).to match(/special/)
      expect(last_response.body).to match(/\[\"foo\", \"bar\"\]/)

      expect(last_response.body).to match(/Enqueue now/)
    end

    context 'when the next execution time is setted' do
      before { Sidekiq::Scheduler.update_job_next_time('Foo Job', "2016-07-11T13:29:47Z") }

      it 'shows the next time for the job' do
        get '/recurring-jobs'

        expect(last_response.body).to match(/2016-07-11T13:29:47Z/)
      end
    end
  end

  describe '/recurring-jobs/:name/toggle' do
    context 'when the job is enabled' do
      it 'disables the job' do
        expect { get "/recurring-jobs/#{URI.escape(enabled_job_name)}/toggle" }
          .to change { Sidekiq::Scheduler.job_enabled?(enabled_job_name) }.from(true).to(false)
      end
    end

    context 'when the job is disabled' do
      it 'enables the job' do
        expect { get "/recurring-jobs/#{URI.escape(disabled_job_name)}/toggle" }
          .to change { Sidekiq::Scheduler.job_enabled?(disabled_job_name) }.from(false).to(true)
      end
    end
  end


  it 'enqueues particular job' do
    job_name = jobs.keys.first
    job = jobs[job_name]

    expect(Sidekiq::Scheduler).to receive(:enqueue_job).with(job)

    get "/recurring-jobs/#{URI.escape(job_name)}/enqueue"
  end

end
