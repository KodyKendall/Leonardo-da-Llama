class AddAdvancedRecurrenceToScheduledTasks < ActiveRecord::Migration[7.2]
  def change
    add_column :scheduled_tasks, :recurring, :boolean
    add_column :scheduled_tasks, :recurrence_unit, :string
    add_column :scheduled_tasks, :recurrence_value, :integer
    add_index :scheduled_tasks, :recurrence_value
    add_column :scheduled_tasks, :scheduled_time, :time
    add_column :scheduled_tasks, :scheduled_days, :string
    add_column :scheduled_tasks, :scheduled_day_of_month, :integer
    add_column :scheduled_tasks, :ends_at, :datetime
  end
end
