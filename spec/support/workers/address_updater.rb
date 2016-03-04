require 'active_job'

class AddressUpdater < ActiveJob::Base

  def perform(user_id)
    @user_id = user_id
  end

end
