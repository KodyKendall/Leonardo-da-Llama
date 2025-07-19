require "twilio"
class Message < ApplicationRecord
  belongs_to :organization

  def deliver!
    Twilio.send_text(sent_to, body, self.organization.twilio_number)
  end

  after_create_commit do
    user = (self.sent_to == self.organization.twilio_number) ? self.sent_from : self.sent_to
    message_thread = MessageThread.new(self.organization)
    messages_in_thread = message_thread.all_messages_to_user(user)
    if messages_in_thread.count == 1
      puts "Broadcasting new message to user #{user}"
      broadcast_append_to "messages"
    else
      puts "Broadcasting replace   message to user message_#{user}"
      broadcast_replace_to "message_#{user}", target: "message_#{user}", partial: "messages/message", locals: { message: self }
    end
  end
end


# message_thread = MessageThread.new(organization)
#     @messages = message_thread.all_organization_threads
#     broadcast_replace_to "messages"
