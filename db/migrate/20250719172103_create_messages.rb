class CreateMessages < ActiveRecord::Migration[7.2]
  def change
    create_table :messages do |t|
      t.string :body
      t.string :sent_to
      t.string :sent_from
      t.string :twilio_sid
      t.string :twilio_error_message
      t.references :organization, null: false, foreign_key: true

      t.timestamps
    end
  end
end
