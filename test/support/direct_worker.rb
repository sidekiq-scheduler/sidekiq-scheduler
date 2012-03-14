class DirectWorker
  include Sidekiq::Worker
  def perform(a, b)
    a + b
  end
end
