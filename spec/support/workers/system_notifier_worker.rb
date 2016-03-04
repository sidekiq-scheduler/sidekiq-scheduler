class SystemNotifierWorker
  include Sidekiq::Worker

  sidekiq_options queue: :system

  def self.perform
  end

end
