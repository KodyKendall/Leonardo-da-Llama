if Rails.env.production? || Rails.env.development?
  Rails.application.config.after_initialize do
    # Start the scheduled task runner if it's not already running
    # This will run every 5 minutes
    ScheduledTaskRunnerJob.perform_in(1.minute) unless Rails.env.test?
  end
end