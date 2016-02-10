class Word < ActiveRecord::Base
  set_table_name :words
  
  belongs_to :vocabulary, :foreign_key => :vocabulary_id
end
