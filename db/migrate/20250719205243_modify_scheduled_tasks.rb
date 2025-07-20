class ModifyScheduledTasks < ActiveRecord::Migration[7.2]
  def change
    add_column :scheduled_tasks, :prompt, :text
    add_column :scheduled_tasks, :agent_name, :string, default: 'llamabot'
    
    # Change the default for job_class
    change_column_default :scheduled_tasks, :job_class, 'LlamaBotTaskJob'
  end
end
