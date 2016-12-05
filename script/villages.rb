file = File.open("#{Rails.root}/db/districts.json").read
new_village_counter = 0
new_ta_counter = 0
new_villages = []
new_tas = []
json = JSON.parse(file)

json.each do |district, traditional_authorities|

	traditional_authorities.each do |ta, villages|
	
		villages.each do |village|
		  @district = District.find_by_name(district).id
		  @ta = TraditionalAuthority.find_by_name_and_district_id(ta,@district).id rescue nil
		  
		  if @ta.blank?
		     #@ta = TraditionalAuthority.create(:name => ta, :district_id => @district, :creator => 1)
		     new_ta_counter += 1
		     new_tas << ta
		     @village = Village.find_by_name_and_traditional_authority_id(village, @ta.id).id rescue nil
		   
					if @village.blank?
					    new_village_counter += 1 
					    new_villages << village
							#Village.create(:name => village, :traditional_authority_id => @ta.id, :creator => 1)
							puts "#{village} in  #{ta} of #{district} created"
					else
							puts "#{village} in  #{ta} of #{district} already exists"
					end 
					 
		  else
		      @village = Village.find_by_name_and_traditional_authority_id(village, @ta).id rescue nil
		      if @village.blank?
		          new_village_counter += 1 
		          new_villages << village
		          #Village.create(:name => village, :traditional_authority_id => @ta, :creator => 1)
		          puts "#{village} in  #{ta} of #{district} created"
		      else
		          puts "#{village} in  #{ta} of #{district} already exists"
		      end 
		  end
			
		end
	
	end

end

puts "Added #{new_village_counter} villages"
puts "Added #{new_ta_counter} tas"

puts "villages #################################################"
puts new_villages.inspect

puts "tas ######################################################"
puts new_tas.uniq.inspect
