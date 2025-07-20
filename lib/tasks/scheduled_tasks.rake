namespace :scheduled_tasks do
  desc "Run all enabled scheduled tasks"
  task run: :environment do
    ScheduledTask.run_pending_tasks
  end
end 