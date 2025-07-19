# frozen_string_literal: true
class PhoneValidator < ActiveModel::EachValidator
  DIGITS_ONLY  = /\A\d{10}\z/.freeze
  STRIP_NONDIG = /\D/.freeze

  def validate_each(record, attr, value)
    digits = value&.gsub(STRIP_NONDIG, '')
    record[attr] = digits                                 # normalise in‑place
    record.errors.add(attr, 'must be exactly 10 digits')  unless digits&.match?(DIGITS_ONLY)
  end
end