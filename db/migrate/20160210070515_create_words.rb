class CreateWords < ActiveRecord::Migration
  def self.up
    create_table :words do |t|
      t.integer :vocabulary_id
      t.string :locale
      t.string :value
      t.integer :voided
      t.string :void_reason
      t.date :date_voided

      t.timestamps
    end
  end

  def self.down
    drop_table :words
  end
end
