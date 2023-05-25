require 'active_job'

class AddressUpdaterKeyword < ActiveJob::Base
  def perform(foo:, hello:)
    @foo = foo
    @hello = hello
  end
end
