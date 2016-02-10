class Vocabulary < ActiveRecord::Base
  set_table_name :vocabularies
  
  cattr_accessor :current_locale

  has_many :words do # , :class_name => "Word", :foreign_key => :vocabulary_id
    def by_locale(locale)
      return self if locale.blank?
      map{|word|
        word if word.locale.match(locale)
      }.compact.last.value rescue ""
    end
  end

  def self.search(string)
    locale = Vocabulary.current_locale
    locale = "en" if Vocabulary.current_locale.nil?
    result = Vocabulary.find_by_value(string).words.by_locale(locale) rescue string
    result = string if result.blank?
    result
  end
  
end
