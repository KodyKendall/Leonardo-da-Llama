# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end
# Create default organization
default_org = Organization.find_or_create_by!(twilio_number: "4153670657") do |org|
  org.name = "Default Organization"
end

# Create default user
default_user = User.find_or_create_by!(email: "kody@llamapress.ai") do |user|
  user.name = "kody@llamapress.ai"
  user.password = "123456"
  user.password_confirmation = "123456"
  user.organization = default_org
  user.phone_number = "8013499924"
end

# Create contact for the other phone number
contact = Contact.find_or_create_by!(phone: "8013499924") do |contact|
  contact.first_name = "Contact"
  contact.last_name = "User"
  contact.organization = default_org
end

# Create sample messages between the twilio number and the contact
sample_messages = [
  {
    body: "Hello! This is a test message from Twilio number.",
    sent_from: "4153670657",
    sent_to: "8013499924",
    twilio_sid: "SM#{SecureRandom.hex(16)}"
  },
  {
    body: "Hi there! Thanks for the message. How can I help you today?",
    sent_from: "8013499924",
    sent_to: "4153670657",
    twilio_sid: "SM#{SecureRandom.hex(16)}"
  },
  {
    body: "I'm interested in learning more about your services.",
    sent_from: "8013499924",
    sent_to: "4153670657",
    twilio_sid: "SM#{SecureRandom.hex(16)}"
  },
  {
    body: "Great! I'd be happy to help. What specific information are you looking for?",
    sent_from: "4153670657",
    sent_to: "8013499924",
    twilio_sid: "SM#{SecureRandom.hex(16)}"
  },
  {
    body: "Could you tell me about your pricing and availability?",
    sent_from: "8013499924",
    sent_to: "4153670657",
    twilio_sid: "SM#{SecureRandom.hex(16)}"
  },
  {
    body: "Absolutely! Let me send you our current pricing information.",
    sent_from: "4153670657",
    sent_to: "8013499924",
    twilio_sid: "SM#{SecureRandom.hex(16)}"
  }
]

sample_messages.each_with_index do |msg_data, index|
  # Space out the messages by a few minutes each
  created_time = index.minutes.ago

  Message.find_or_create_by!(twilio_sid: msg_data[:twilio_sid]) do |message|
    message.body = msg_data[:body]
    message.sent_from = msg_data[:sent_from]
    message.sent_to = msg_data[:sent_to]
    message.organization = default_org
    message.created_at = created_time
    message.updated_at = created_time
  end
end

puts "Seeded:"
puts "- 1 Organization (#{default_org.name}) with Twilio number: #{default_org.twilio_number}"
puts "- 1 User (#{default_user.name}) in organization: #{default_org.name}"
puts "- 1 Contact (#{contact.first_name} #{contact.last_name}) with phone: #{contact.phone}"
puts "- #{sample_messages.count} Messages between #{default_org.twilio_number} and #{contact.phone}"
