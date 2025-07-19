class ScheduledTask < ApplicationRecord
  validates :name, presence: true, uniqueness: true
  validates :job_class, presence: true

  scope :enabled, -> { where(enabled: true) }

  def self.run_pending_tasks
    enabled.each do |task|
      job_class = task.job_class.constantize
      
      # Use Sidekiq's perform_async instead of perform_later
      if job_class.respond_to?(:perform_async)
        job_class.perform_async(*task.args.values)
      else
        # Fallback to ActiveJob
        job_class.perform_later(*task.args.values)
      end
      
      task.update!(last_run_at: Time.current)
    end
  end
end
