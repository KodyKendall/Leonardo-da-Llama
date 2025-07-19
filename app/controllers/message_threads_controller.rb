class MessageThreadsController < ApplicationController
  def index
    message_thread = MessageThread.new(current_organization)
    @phone_number = params[:phone_number]
    @thread_messages = message_thread.all_messages_to_user(params[:phone_number])
  end
end
