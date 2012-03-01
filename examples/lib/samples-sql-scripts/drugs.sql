generics = {};  Drug.all.each{|drug| generics[drug.concept_id] = []; Drug.find(:all, :conditions => ["concept_id = ? AND retired = 0", drug.concept_id]).each {|d| generics[drug.concept_id] << d.name; }.compact.uniq rescue [] }; generics



