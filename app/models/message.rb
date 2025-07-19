require "twilio"
class Message < ApplicationRecord
  belongs_to :organization

  def deliver!
    Twilio.send_text(sent_to, body, self.organization.twilio_number)
  end
end
