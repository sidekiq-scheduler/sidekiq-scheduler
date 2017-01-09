require 'active_job'

class EmailSender < ActiveJob::Base
  queue_as :email

  def perform
  end

end
