class JobConfigurationsFaker

  def self.some_worker(options = {})
    {
      'class' => 'SomeWorker',
      'queue' => 'low',
      'args' => []
    }.merge(options)
  end

end
