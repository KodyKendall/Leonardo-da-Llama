class LlamaBotTaskJob
  include Sidekiq::Job
  include LlamaBotRails::ControllerExtensions

  def perform(task_id)
    task = ScheduledTask.find(task_id)
    
    # Generate a temporary API token for the agent
    api_token = Rails.application.message_verifier(:llamabot_ws).generate(
      { session_id: SecureRandom.uuid, user_id: User.first.id },
      expires_in: 30.minutes
    )

    # Prepare agent parameters similar to what we see in the messages controller
    agent_params = {
      message: task.prompt,
      thread_id: "scheduled_task_#{task.id}",
      agent_name: task.agent_name,
      api_token: api_token,
      agent_prompt: task.prompt
    }

    # Send to LlamaBot and process responses
    responses = LlamaBotRails::LlamaBot.send_agent_message(agent_params).to_a
    Rails.logger.info("LlamaBot responses for scheduled task #{task.id}: #{responses}")
    
    # Update the task's last run time
    task.update!(last_run_at: Time.current)
  end
end 