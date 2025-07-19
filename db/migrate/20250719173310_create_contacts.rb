class CreateContacts < ActiveRecord::Migration[7.2]
  def change
    create_table :contacts do |t|
      t.string :first_name
      t.string :last_name
      t.string :phone
      t.string :email
      t.string :notes
      t.references :organization, null: false, foreign_key: true

      t.timestamps
    end
  end
end
