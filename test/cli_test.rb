require 'test_helper'
require 'sidekiq-scheduler/cli'
require 'tempfile'

class CliTest < MiniTest::Unit::TestCase
  describe 'with cli' do
    before do
      @cli = new_cli
    end

    describe 'with config file' do
      before do
        @cli.parse(['sidekiq', '-C', './test/config.yml'])
      end

      it 'sets the resolution of the scheduler timer' do
        assert_equal 30, Sidekiq.options[:resolution]
      end
    end

    def new_cli
      cli = Sidekiq::CLI.new
      def cli.die(code)
        @code = code
      end

      def cli.valid?
        !@code
      end
      cli
    end
  end
end
