require 'simplecov'
require 'coveralls'

SimpleCov.start
Coveralls.wear!

require 'sidekiq'
require 'sidekiq/testing'
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
end
