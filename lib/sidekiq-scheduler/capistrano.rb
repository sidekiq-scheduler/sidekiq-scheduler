Capistrano::Configuration.instance.load do
  before 'deploy',         'sidekiq_scheduler:quiet'
  after  'deploy:stop',    'sidekiq_scheduler:stop'
  after  'deploy:start',   'sidekiq_scheduler:start'
  after  'deploy:restart', 'sidekiq_scheduler:restart'

  _cset(:sidekiq_timeout) { 10 }
  _cset(:sidekiq_role) { :app }

  namespace :sidekiq_scheduler do

    desc 'Quiet sidekiq-scheduler with sidekiq (stop accepting new work)'
    task :quiet, roles: lambda { fetch(:sidekiq_role) } do
      bundle_cmd = fetch(:bundle_cmd, 'bundle')
      pid_file = "#{current_path}/tmp/pids/sidekiq.pid"
      quiet_cmd = "#{bundle_cmd} exec sidekiqctl quiet #{pid_file}"

      run "cd #{current_path} && if [ -f #{pid_file} ]; then #{quiet_cmd} ; fi"
    end

    desc 'Stop sidekiq-scheduler with sidekiq'
    task :stop, roles: lambda { fetch(:sidekiq_role) } do
      bundle_cmd = fetch(:bundle_cmd, 'bundle')
      pid_file = "#{current_path}/tmp/pids/sidekiq.pid"
      timeout = fetch(:sidekiq_timeout)
      stop_cmd = "#{bundle_cmd} exec sidekiqctl stop #{pid_file} #{timeout}"

      run "cd #{current_path} && if [ -f #{pid_file} ]; then #{stop_cmd} ; fi"
    end

    desc 'Start sidekiq-scheduler with sidekiq'
    task :start, roles: lambda { fetch(:sidekiq_role) } do
      rails_env = fetch(:rails_env, 'production')
      bundle_cmd = fetch(:bundle_cmd, 'bundle')
      log_file = "#{current_path}/log/sidekiq.log 2>&1 &"
      pid_file = "#{current_path}/tmp/pids/sidekiq.pid"
      start_cmd  = "#{bundle_cmd} exec sidekiq-scheduler start "
      start_cmd += "-e #{rails_env} "
      start_cmd += "-C #{current_path}/config/sidekiq.yml "
      start_cmd += "-P #{pid_file} "
      exec_cmd = "nohup #{start_cmd}"

      run "cd #{current_path} ; nohup #{exec_cmd} >> #{log_file}", pty: false
    end

    desc 'Restart sidekiq-scheduler with sidekiq'
    task :restart, roles: lambda { fetch(:sidekiq_role) } do
      stop
      start
    end

  end
end

