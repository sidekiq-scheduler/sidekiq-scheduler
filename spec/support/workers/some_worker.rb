class SomeWorker
  include Sidekiq::Worker

  def self.perform(_, _)
  end

end
