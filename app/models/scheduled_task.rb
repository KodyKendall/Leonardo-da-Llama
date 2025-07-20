class ScheduledTask < ApplicationRecord
  VALID_RECURRENCE_UNITS = %w[minutes hours days weeks months].freeze
  DAYS_OF_WEEK = %w[monday tuesday wednesday thursday friday saturday sunday].freeze

  validates :name, presence: true, uniqueness: true
  validates :job_class, presence: true
  validates :prompt, presence: true, if: :llama_bot_task?
  
  # Recurrence validations
  validates :recurrence_unit, inclusion: { in: VALID_RECURRENCE_UNITS }, if: :recurring
  validates :recurrence_value, numericality: { greater_than: 0 }, if: :recurring
  validates :scheduled_time, presence: true, if: -> { recurring && !minutes_or_hours? }
  validates :scheduled_day_of_month, numericality: { 
    greater_than_or_equal_to: 1, 
    less_than_or_equal_to: 31,
    allow_nil: true 
  }
  validate :validate_scheduled_days

  scope :enabled, -> { where(enabled: true) }
  scope :recurring, -> { where(recurring: true) }
  scope :non_recurring, -> { where(recurring: false) }

  after_create :initialize_next_run, if: :recurring?

  def self.run_pending_tasks
    enabled.each do |task|
      next if task.ends_at&.past?
      next unless task.due_for_run?

      if task.llama_bot_task?
        LlamaBotTaskJob.perform_async(task.id)
      else
        job_class = task.job_class.constantize
        
        if job_class.respond_to?(:perform_async)
          job_class.perform_async(*task.args.values)
        else
          job_class.perform_later(*task.args.values)
        end
      end
      
      task.update!(last_run_at: Time.current)
      task.schedule_next_run if task.recurring?
    end
  end

  def llama_bot_task?
    job_class == 'LlamaBotTaskJob'
  end

  def schedule_next_run
    next_run = calculate_next_run
    update!(next_run_at: next_run)
  end

  def due_for_run?
    return true if !recurring? && (last_run_at.nil? || next_run_at&.past?)
    return false if next_run_at.nil? || next_run_at.future?
    
    if recurring?
      case recurrence_unit
      when 'minutes', 'hours'
        last_run_at.nil? || Time.current >= next_run_at
      else
        current_time = Time.current
        scheduled_time_today = scheduled_time.present? ? 
          current_time.change(hour: scheduled_time.hour, min: scheduled_time.min) :
          current_time

        if recurrence_unit == 'months' && scheduled_day_of_month.present?
          return current_time.day == scheduled_day_of_month && current_time >= scheduled_time_today
        end

        if scheduled_days.present?
          return scheduled_days.include?(current_time.strftime('%A').downcase) && 
                 current_time >= scheduled_time_today
        end

        current_time >= scheduled_time_today
      end
    else
      false
    end
  end

  private

  def initialize_next_run
    return if next_run_at.present?
    self.next_run_at = calculate_next_run
    save!
  end

  def calculate_next_run
    return nil if ends_at&.past?
    current_time = Time.current

    case recurrence_unit
    when 'minutes'
      current_time + recurrence_value.minutes
    when 'hours'
      current_time + recurrence_value.hours
    when 'days'
      next_time = scheduled_time.present? ? 
        current_time.change(hour: scheduled_time.hour, min: scheduled_time.min) :
        current_time
      next_time += 1.day if next_time <= current_time
      next_time + (recurrence_value - 1).days
    when 'weeks'
      if scheduled_days.present?
        next_day = find_next_scheduled_day(current_time)
        next_time = current_time.next_occurring(next_day.to_sym)
        next_time = next_time.change(hour: scheduled_time.hour, min: scheduled_time.min)
        next_time += (recurrence_value - 1).weeks if next_time <= current_time
        next_time
      else
        next_time = current_time.change(hour: scheduled_time.hour, min: scheduled_time.min)
        next_time += 1.week if next_time <= current_time
        next_time + (recurrence_value - 1).weeks
      end
    when 'months'
      if scheduled_day_of_month.present?
        next_time = current_time.change(
          day: scheduled_day_of_month,
          hour: scheduled_time.hour,
          min: scheduled_time.min
        )
        next_time = next_time.next_month if next_time <= current_time
        next_time + (recurrence_value - 1).months
      else
        next_time = current_time.change(hour: scheduled_time.hour, min: scheduled_time.min)
        next_time = next_time.next_month if next_time <= current_time
        next_time + (recurrence_value - 1).months
      end
    end
  end

  def find_next_scheduled_day(from_time)
    return nil if scheduled_days.blank?
    
    current_day = from_time.strftime('%A').downcase
    ordered_days = DAYS_OF_WEEK.rotate(DAYS_OF_WEEK.index(current_day))
    
    ordered_days.each do |day|
      return day if scheduled_days.include?(day)
    end
    
    scheduled_days.first # fallback to first scheduled day
  end

  def validate_scheduled_days
    return unless recurring? && scheduled_days.present?
    
    invalid_days = scheduled_days - DAYS_OF_WEEK
    if invalid_days.any?
      errors.add(:scheduled_days, "contains invalid days: #{invalid_days.join(', ')}")
    end
  end

  def minutes_or_hours?
    %w[minutes hours].include?(recurrence_unit)
  end
end
