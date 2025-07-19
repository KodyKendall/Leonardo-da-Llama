class ScheduledTask < ApplicationRecord
  validates :name, presence: true, uniqueness: true
  validates :job_class, presence: true
  validates :prompt, presence: true, if: :llama_bot_task?

  scope :enabled, -> { where(enabled: true) }

  def self.run_pending_tasks
    enabled.each do |task|
      if task.llama_bot_task?
        LlamaBotTaskJob.perform_async(task.id)
      else
        job_class = task.job_class.constantize
        
        # Use Sidekiq's perform_async instead of perform_later
        if job_class.respond_to?(:perform_async)
          job_class.perform_async(*task.args.values)
        else
          # Fallback to ActiveJob
          job_class.perform_later(*task.args.values)
        end
      end
      
      task.update!(last_run_at: Time.current)
    end
  end

  def llama_bot_task?
    job_class == 'LlamaBotTaskJob'
  end
end
