require 'test_helper'
require 'sidekiq-scheduler/web'
require 'rack/test'

class WebTest < MiniTest::Test
  describe 'sidekiq-scheduler web' do
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
      # Sidekiq::WebHelpers expects the Redis client to return an id
      Sidekiq.redis { |conn| conn.client.stubs(:id).returns('redis://127.0.0.1:1234/0') }

      Sidekiq.schedule = jobs
    end

    it 'shows schedule' do
      get '/recurring-jobs'

      assert(last_response.ok?)

      assert_match(/Foo Job/, last_response.body)
      assert_match(/FooClass/, last_response.body)
      assert_match(/0 \* \* \* \* US\/Eastern/, last_response.body)
      assert_match(/default/, last_response.body)
      assert_match(/\[42\]/, last_response.body)
      assert_match(/Does foo things\./, last_response.body)

      assert_match(/Bar Job/, last_response.body)
      assert_match(/BarClass/, last_response.body)
      assert_match(/1h/, last_response.body)
      assert_match(/special/, last_response.body)
      assert_match(/\[\"foo\", \"bar\"\]/, last_response.body)

      assert_match(/Enqueue now/, last_response.body)
    end

    it 'enqueues particular job' do
      job_name = jobs.keys.first
      job = jobs[job_name]

      Sidekiq::Scheduler.expects(:enqueue_job).with(job)

      get "/recurring-jobs/#{URI.escape(job_name)}/enqueue"

      assert(last_response.redirect?)
      follow_redirect!
      assert_equal(last_request.path, '/recurring-jobs')
    end
  end
end
