class ScheduleFaker

  def self.cron_schedule(options = {})
    default_cron_arg = ['* * * * *']
    allow_overlapping = options.delete('allow_overlapping')

    default_cron_arg << {'allow_overlapping' => allow_overlapping} if allow_overlapping

    options = {
      'cron'  => default_cron_arg.size == 1 ? default_cron_arg[0] : default_cron_arg
    }.merge(default_options(options))
  end

  def self.every_schedule(options = {})
    default_every_arg = ['30s']
    first_in = options.delete('first_in')

    default_every_arg << {'first_in' => first_in} if first_in

    options = {
      'every' => default_every_arg
    }.merge(default_options(options))
  end

  def self.at_schedule(options = {})
    at = options.delete(:at) || Time.now

    options = {
      'at' => at.strftime('%Y/%m/%d %H:%M')
    }.merge(default_options(options))
  end

  def self.in_schedule(options = {})
    options = {
      'in' => '1d'
    }.merge(default_options(options))
  end

  def self.invalid_schedule(options = {})
    default_options(options)
  end

  def self.default_options(options = {})
    {
      'class' => 'SomeWorker',
      'args'  => 'some_arg'
    }.merge(options)
  end

end
