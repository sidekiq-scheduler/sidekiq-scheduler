require 'sidekiq-scheduler/web'
require 'rack/test'

describe Sidekiq::Web do
  include Rack::Test::Methods

  let(:app) { Sidekiq::Web }

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
    Sidekiq.redis(&:flushall)
    Sidekiq.schedule = jobs
  end

  describe 'GET /recurring-jobs' do
    subject { get '/recurring-jobs' }

    context 'when the next execution time is not setted' do
      it do
        pending 'due to failure in mock_redis when pipelining array replies'
        is_expected.to be_successful
      end

      describe 'response body' do
        subject do
          get '/recurring-jobs'
          last_response.body
        end

        it 'shows schedule' do
          pending 'due to failure in mock_redis when pipelining array replies'
          is_expected.to match(/Foo Job/)
          is_expected.to match(/FooClass/)
          is_expected.to match(/0 \* \* \* \* US\/Eastern/)
          is_expected.to match(/default/)
          is_expected.to match(/\[42\]/)
          is_expected.to match(/Does foo things\./)

          is_expected.to match(/Bar Job/)
          is_expected.to match(/BarClass/)
          is_expected.to match(/1h/)
          is_expected.to match(/special/)
          is_expected.to match(/\[\"foo\", \"bar\"\]/)

          is_expected.to match(/Enqueue now/)
        end
      end
    end

    context 'when the next execution time is setted' do
      before { SidekiqScheduler::Utils.update_job_next_time(enabled_job_name, '2016-07-11T13:29:47Z') }

      it do
        pending 'due to failure in mock_redis when pipelining array replies'
        is_expected.to be_successful
      end

      describe 'response body' do
        subject do
          get '/recurring-jobs'
          last_response.body
        end

        it do
          pending 'due to failure in mock_redis when pipelining array replies'
          is_expected.to match(/2016-07-11T13:29:47Z/)
        end
      end
    end
  end

  describe '/recurring-jobs/:name/toggle' do
    subject { get "/recurring-jobs/#{CGI.escape(enabled_job_name)}/toggle" }

    it 'toggles job enabled flag' do
      expect { subject }
        .to change { SidekiqScheduler::Scheduler.job_enabled?(enabled_job_name) }.from(true).to(false)
    end

    it 'reloads the schedule' do
      expect(Sidekiq).to receive(:reload_schedule!)

      subject
    end
  end

  describe 'GET /recurring-jobs/:name/enqueue' do
    subject { get "/recurring-jobs/#{CGI.escape(job_name)}/enqueue" }

    let(:job_name) { enabled_job_name }
    let(:job) { jobs[job_name] }

    before { SidekiqScheduler::Scheduler.instance = SidekiqScheduler::Scheduler.new }

    it 'enqueues particular job' do
      expect(SidekiqScheduler::Scheduler.instance).to receive(:enqueue_job).with(job)
      subject
    end
  end
end
