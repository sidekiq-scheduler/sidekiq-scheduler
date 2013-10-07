require 'test_helper'
require 'sidekiq-scheduler/cli'
require 'tempfile'

class CliTest < Minitest::Test

  describe 'with cli' do

    before do
      Celluloid.boot
      @cli = Sidekiq::CLI.instance
    end

    describe 'with config file' do
      before do
        @cli.parse(['sidekiq', '-C', './test/config.yml'])
      end

      it 'sets the resolution of the scheduler timer' do
        assert_equal 30, Sidekiq.options[:resolution]
      end
    end

  end

end
