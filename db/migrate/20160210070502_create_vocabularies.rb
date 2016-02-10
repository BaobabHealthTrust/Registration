class CreateVocabularies < ActiveRecord::Migration
  def self.up
    create_table :vocabularies do |t|
      t.string :value
      t.integer :voided
      t.string :void_reason
      t.date :date_voided

      t.timestamps
    end
  end

  def self.down
    drop_table :vocabularies
  end
end
