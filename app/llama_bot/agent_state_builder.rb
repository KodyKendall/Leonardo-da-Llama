# frozen_string_literal: true
#
# Customize the params sent to your LangGraph agent here.
# Uncomment the line in the initializer to activate this builder.
module LeonardoDaLlama
  class AgentStateBuilder
    def initialize(params:, context:)
      @params = params
      @context = context
    end

    def build
      {
        message: @params["message"], # Rails param from JS/chat UI. This is the user's message to the agent.
        thread_id: @params["thread_id"], # This is the thread id for the agent. It is used to track the conversation history.
        api_token: @context["api_token"], # This is an authenticated API token for the agent, so that it can authenticate with us. (It may need access to resources on our Rails app, such as the Rails Console.)
        agent_prompt: LlamaBotRails.agent_prompt_text, # System prompt instructions for the agent. Can be customized in app/llama_bot/prompts/agent_prompt.txt
        agent_name: "llamabot" # This routes to the appropriate LangGraph agent as defined in LlamaBot/langgraph.json, and enables us to access different agents on our LlamaBot server.
      }
    end
  end
end 