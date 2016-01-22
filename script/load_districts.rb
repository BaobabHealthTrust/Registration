file = File.open(Rails.root.join('db','districts.json')).read
counter = 0
json = JSON.parse(file)

json.each do |district, traditional_authorities|

	traditional_authorities.each do |ta, villages|
	ds = DDEDistrict.find_by_name(district) 
	 
	tad = DDETraditionalAuthority.find_by_name_and_district_id(ta,ds.district_id)
	if tad.blank?
	   tad = DDETraditionalAuthority.create(:name => ta, :district_id => ds.district_id, :creator => 1, :date_created => Date.today)
	end
	
		villages.each do |village|
		
		 vs = DDEVillage.find_by_name_and_traditional_authority_id(village, tad.traditional_authority_id)
		
			if vs.blank?
			   puts " 1 " + ta.inspect
			   puts " 2 " + district.inspect
			   puts " 3 " + village.inspect
			   puts " 4 " + tad.name.inspect
			   counter +=1
				 DDEVillage.create(:name => village, :traditional_authority_id => tad.traditional_authority_id, :creator => 1, :date_created => Date.today)
				 puts "#{village} village in TA #{ta} in #{district} district created." 
			else
				 puts "#{village} village in TA #{ta} in #{district}  district already exists." 
			end
		
		end
	
	end

end
puts "Added #{counter} villages"
