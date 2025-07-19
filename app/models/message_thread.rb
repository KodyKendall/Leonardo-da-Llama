class MessageThread
  attr_accessor :organization

  def initialize(organization)
    @organization = organization
  end

  def all_organization_threads
    messages = []
    all_users.each do |user|
      message = organization.messages.where("(sent_to = ? AND sent_from = ?) OR (sent_to = ? AND sent_from = ?)", user, twilio_number, twilio_number, user).order(created_at: :desc).first
      messages << message if message
    end
    messages
  end

  def all_messages_to_user(user)
    organization.messages.where("(sent_to = ? AND sent_from = ?) OR (sent_to = ? AND sent_from = ?)", user, twilio_number, twilio_number, user).order(created_at: :desc)
  end

  def all_users
    (all_bot_messages.select(:sent_to).distinct.pluck(:sent_to) + all_user_messages.select(:sent_from).distinct.pluck(:sent_from)).uniq
  end

  def all_bot_messages
    organization.messages.where(sent_from: twilio_number)
  end

  def all_user_messages
    organization.messages.where(sent_to: twilio_number)
  end

  def twilio_number
    organization.twilio_number
  end
end
