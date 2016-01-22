require 'fastercsv'

FasterCSV.foreach(Rails.root.join('db','missing_villages.csv')) do |row|
 district = DDEDistrict.find_by_name(row[0]) 
 if district.blank? 
  next
 end 
 ta = DDETraditionalAuthority.find_by_name_and_district_id(row[1],district.district_id)
 
 if ta.blank? 
  next
 end 
 
 village = DDEVillage.find_by_name_and_traditional_authority_id(row[2], ta.traditional_authority_id)
  
 if village.blank?
   DDEVillage.create(:name => row[2], :traditional_authority_id => ta.traditional_authority_id, :creator => 1, :date_created => Date.today)
   puts "#{row[2]} village in TA #{row[1]} in #{row[0]} district created." 
 else
   puts "#{row[2]} village in TA #{row[1]} in #{row[0]}  district already exists." 
 end
end
