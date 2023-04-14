require 'pry'
describe SidekiqScheduler::Scheduler do
  it "loads schedule" do
    Sidekiq.schedule = {
      "hello_world" => {
        "class"=> "HelloWorld",
        "description"=>"Testing out scheduled jobs",
        "cron"=>"0 12 * * * America/New_York"
      }
    }
    SidekiqScheduler::Scheduler.instance.enabled = true
    SidekiqScheduler::Scheduler.instance.reload_schedule!
  end
end
