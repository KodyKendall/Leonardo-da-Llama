class CreateScheduledTasks < ActiveRecord::Migration[7.2]
  def change
    create_table :scheduled_tasks do |t|
      t.string :name
      t.string :cron_schedule
      t.string :job_class
      t.json :args
      t.boolean :enabled
      t.datetime :last_run_at
      t.datetime :next_run_at

      t.timestamps
    end
  end
end
