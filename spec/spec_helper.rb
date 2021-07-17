require 'simplecov'

SimpleCov.start do
  minimum_coverage 97.91
end

require 'sidekiq'
require 'sidekiq/testing'
require 'sidekiq-scheduler'
require 'json'
require 'timecop'

# Load all support files
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].sort.each { |f| require f }

$TESTING = true

RSpec.configure do |config|
  config.after(:each) do
    Timecop.return
  end

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.profile_examples = 10

  config.order = :random
end
