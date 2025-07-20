class ScheduledTaskRunnerJob
  include Sidekiq::Job

  def perform
    ScheduledTask.run_pending_tasks
    
    # Schedule the next run in 5 minutes
    ScheduledTaskRunnerJob.perform_in(5.minutes)
  end
end
