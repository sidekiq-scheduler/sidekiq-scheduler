require 'hashie'

module SidekiqScheduler
  class ConfigHash < Hash
    include Hashie::Extensions::MergeInitializer
    include Hashie::Extensions::IndifferentAccess
  end
end
