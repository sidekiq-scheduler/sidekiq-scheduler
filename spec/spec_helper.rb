require 'simplecov'
require 'coveralls'

SimpleCov.start
Coveralls.wear!

require 'sidekiq'
require 'sidekiq-scheduler'
require 'multi_json'
require 'timecop'

# Load all support files
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }

RSpec.configure do |config|

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.profile_examples = 10

  config.order = :random

  def process_parameters(config)
    config['class'] = config['class'].constantize if config['class'].is_a?(String)

    if config['args'].is_a?(Hash)
      config['args'].symbolize_keys! if config['args'].respond_to?(:symbolize_keys!)
    else
      config['args'] = Array(config['args'])
    end

    config
  end

end
