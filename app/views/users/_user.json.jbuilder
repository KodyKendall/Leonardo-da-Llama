json.extract! user, :id, :name, :phone_number, :organization_id, :created_at, :updated_at
json.url user_url(user, format: :json)
