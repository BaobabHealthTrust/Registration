# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ :name => 'Chicago' }, { :name => 'Copenhagen' }])
#   Mayor.create(:name => 'Daley', :city => cities.first)
vocabulary_data = File.read('db/data/vocabulary.json')
vocabulary_json = JSON.parse(vocabulary_data)

word_data = File.read('db/data/word.json')
word_json = JSON.parse(word_data)

vocabulary_json.each do |values|
  values.each do |k, v|
    vocabulary = Vocabulary.find(v["id"]) rescue nil
    next unless vocabulary.blank?
    Vocabulary.create(v)
  end
end

word_json.each do |values|
  values.each do |k, v|
    word = Word.find(v["id"]) rescue nil
    next unless word.blank?
    Word.create(v)
  end
end

