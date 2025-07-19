# config/initializers/scheduled_tasks.rb
#
# Skip during image builds and in the web process; run only inside
# a real Sidekiq worker.
return unless defined?(Sidekiq) && Sidekiq.server?

if Rails.env.production? || Rails.env.development?
  Rails.application.config.after_initialize do
    ScheduledTaskRunnerJob.perform_in(1.minute) unless Rails.env.test?
  end
end
