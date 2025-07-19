class Organization < ApplicationRecord
    has_many :users, dependent: :destroy
    has_many :messages, dependent: :destroy

    validates :twilio_number, phone: true, allow_blank: false
end
