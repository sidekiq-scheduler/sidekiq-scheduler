require 'sidekiq-scheduler/web'
require 'rack/test'

describe Sidekiq::Web do
  include Rack::Test::Methods

  def app
    Sidekiq::Web
  end

  let(:jobs) do
    {
      'Foo Job' => {
        'class' => 'FooClass',
        'cron' => '0 * * * * US/Eastern',
        'args' => [42],
        'description' => 'Does foo things.'
      },

      'Bar Job' => {
        'class' => 'BarClass',
        'every' => '1h',
        'args' => ['foo', 'bar'],
        'queue' => 'special'
      }
    }
  end

  before do
    Sidekiq.schedule = jobs
  end

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

  it 'enqueues particular job' do
    job_name = jobs.keys.first
    job = jobs[job_name]

    expect(Sidekiq::Scheduler).to receive(:enqueue_job).with(job)

    get "/recurring-jobs/#{URI.escape(job_name)}/enqueue"
  end

end
