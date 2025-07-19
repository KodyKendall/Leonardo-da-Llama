json.extract! message, :id, :body, :sent_to, :sent_from, :twilio_sid, :twilio_error_message, :organization_id, :created_at, :updated_at
json.url message_url(message, format: :json)
